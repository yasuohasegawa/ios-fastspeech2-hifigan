import torch
import torchaudio
import torch.nn as nn
import coremltools as ct
import numpy as np
import json
from espnet2.bin.tts_inference import Text2Speech
from parallel_wavegan.models import HiFiGANGenerator
import yaml
import sys
import os


print("--- Loading FastSpeech2 model ---")
model_tag = "espnet/kan-bayashi_ljspeech_fastspeech2"
tts = Text2Speech.from_pretrained(model_tag=model_tag, device="cpu")

print("--- Manually loading HiFi-GAN vocoder ---")
vocoder_config_path = os.path.expanduser("~/.cache/parallel_wavegan/ljspeech_hifigan.v1/config.yml")
vocoder_ckpt_path = os.path.expanduser("~/.cache/parallel_wavegan/ljspeech_hifigan.v1/checkpoint-2500000steps.pkl")

try:
    with open(vocoder_config_path) as f:
        config = yaml.safe_load(f)
    checkpoint = torch.load(vocoder_ckpt_path, map_location="cpu")
    vocoder = HiFiGANGenerator(**config["generator_params"])
    vocoder.load_state_dict(checkpoint["model"]["generator"])
    vocoder.remove_weight_norm()
    vocoder.eval()
    tts.vocoder = vocoder
    print("✅ HiFi-GAN vocoder loaded and attached to TTS.")
except Exception as e:
    print(f"❌ Failed to load vocoder: {e}")
    sys.exit(1)

tts.model.eval()


tokens = tts.train_args.token_list
phoneme_map = {phoneme: i for i, phoneme in enumerate(tokens)}
with open("ljspeech_phoneme_map.json", "w", encoding="utf-8") as f:
    json.dump(phoneme_map, f, ensure_ascii=False, indent=2)
print("✅ Phoneme map saved")

sample_text = "Hello world, this is a test sentence."
with torch.no_grad():
    processed_input = tts.preprocess_fn("1", {"text": sample_text})
    input_ids = torch.from_numpy(processed_input["text"]).unsqueeze(0)

print(f"Sample text: '{sample_text}'")
print(f"Generated input_ids shape: {input_ids.shape}")


print("\nConverting Model 1: FastSpeech2Encoder...")

class EncoderWrapper(torch.nn.Module):
    def __init__(self, fastspeech2):
        super().__init__()
        self.encoder = fastspeech2.encoder
        self.duration_predictor = fastspeech2.duration_predictor
        self.pitch_predictor = fastspeech2.pitch_predictor
        self.energy_predictor = fastspeech2.energy_predictor

    def forward(self, x):
        hs, _ = self.encoder(x, None)
        d_outs = self.duration_predictor(hs)
        p_outs = self.pitch_predictor(hs)
        e_outs = self.energy_predictor(hs)
        return hs, d_outs, p_outs, e_outs

encoder_wrapper = EncoderWrapper(tts.model.tts)
encoder_wrapper.eval()

traced_encoder = torch.jit.trace(encoder_wrapper, input_ids, strict=False)

encoder_mlmodel = ct.convert(
    traced_encoder,
    inputs=[ct.TensorType(name="input_ids", shape=[1, ct.RangeDim(1, 500)], dtype=np.int32)],
    outputs=[
        ct.TensorType(name="encoded_phonemes"),
        ct.TensorType(name="log_durations"),
        ct.TensorType(name="pitch_predictions"),
        ct.TensorType(name="energy_predictions"),
    ],
    compute_units=ct.ComputeUnit.CPU_AND_NE,
)
encoder_mlmodel.save("FastSpeech2Encoder_en.mlpackage")
print("✅ FastSpeech2Encoder_en.mlpackage saved successfully.")



print("\nConverting Model 2: FastSpeech2Decoder...")

# --- Generate example inputs for the Decoder ---
with torch.no_grad():
    hs, d_outs, p_outs, e_outs = encoder_wrapper(input_ids)
    durations = torch.clamp((torch.exp(d_outs) - 1), min=1).long().squeeze(0)
    
    hs_expanded = tts.model.tts.length_regulator(hs, durations)
    
    p_expanded = tts.model.tts.length_regulator(p_outs, durations).squeeze(-1)
    e_expanded = tts.model.tts.length_regulator(e_outs, durations).squeeze(-1)

class DecoderWrapper(nn.Module):
    def __init__(self, model):
        super().__init__()
        self.pitch_embed = model.pitch_embed
        self.energy_embed = model.energy_embed
        self.decoder = model.decoder
        self.feat_out = FeatOutWrapper(model.feat_out, model.odim)
        self.postnet = model.postnet

    def forward(self, hs_exp, p_exp, e_exp):
        # p_exp is now (B, T_exp). unsqueeze(1) makes it (B, 1, T_exp), which is the
        # correct 3D shape for the conv1d embedding layer.
        p_emb = self.pitch_embed(p_exp.unsqueeze(1)).transpose(1, 2)
        e_emb = self.energy_embed(e_exp.unsqueeze(1)).transpose(1, 2)
        combined_features = hs_exp + p_emb + e_emb

        zs, _ = self.decoder(combined_features, None)
        before_outs = self.feat_out(zs)
        after_outs = before_outs + self.postnet(before_outs.transpose(1, 2)).transpose(1, 2)
        
        return after_outs

class FeatOutWrapper(nn.Module):
    def __init__(self, feat_out, odim):
        super().__init__()
        self.feat_out = feat_out
        self.odim = odim
    def forward(self, x):
        out = self.feat_out(x)
        return out.view(out.size(0), -1, self.odim)

decoder_wrapper = DecoderWrapper(tts.model.tts)
decoder_wrapper.eval()

# Trace with the three separate expanded tensors (shapes are now correct)
traced_decoder = torch.jit.trace(decoder_wrapper, (hs_expanded, p_expanded, e_expanded), strict=False)

decoder_mlmodel = ct.convert(
    traced_decoder,
    inputs=[
        ct.TensorType(name="expanded_hidden_states", shape=[1, ct.RangeDim(10, 5000), 384], dtype=np.float32),
        ct.TensorType(name="expanded_pitch", shape=[1, ct.RangeDim(10, 5000)], dtype=np.float32),
        ct.TensorType(name="expanded_energy", shape=[1, ct.RangeDim(10, 5000)], dtype=np.float32),
    ],
    outputs=[ct.TensorType(name="mel_spectrogram")],
    compute_units=ct.ComputeUnit.CPU_AND_NE,
)
decoder_mlmodel.save("FastSpeech2Decoder_en.mlpackage")
print("✅ FastSpeech2Decoder_en.mlpackage saved successfully.")


print("\nConverting Model 3: HiFiGAN Vocoder...")

class HiFiGANWrapper(torch.nn.Module):
    def __init__(self, vocoder):
        super().__init__()
        self.vocoder = vocoder
    def forward(self, mel):
        wav, *_ = self.vocoder(mel)
        return wav

with torch.no_grad():
    sample_mel_from_decoder = decoder_wrapper(hs_expanded, p_expanded, e_expanded)
    sample_mel_for_vocoder = sample_mel_from_decoder.transpose(1, 2)

wrapped_hifigan = HiFiGANWrapper(tts.vocoder)
traced_hifigan = torch.jit.trace(wrapped_hifigan, sample_mel_for_vocoder, strict=False)

hifigan_mlmodel = ct.convert(
    traced_hifigan,
    inputs=[ct.TensorType(name="mel_spectrogram", shape=[1, 80, ct.RangeDim(10, 5000)], dtype=np.float32)],
    outputs=[ct.TensorType(name="waveform")],
    compute_units=ct.ComputeUnit.CPU_ONLY,
)
hifigan_mlmodel.save("HiFiGAN_en.mlpackage")
print("✅ HiFiGAN_en.mlpackage saved successfully.")

print("\n🎉 ALL MODELS CONVERTED SUCCESSFULLY! 🎉")
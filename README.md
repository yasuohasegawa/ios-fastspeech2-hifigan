## 🗣 iOS FastSpeech2 + HiFi-GAN

This project integrates FastSpeech2 and HiFi-GAN for on-device TTS (Text-to-Speech) on iOS. It currently supports both **Japanese** and **English**, with **one voice per language**.

Model export to Core ML and some challenging implementation parts were assisted by **ChatGPT** and **Gemini**.

---

### 📦 Models Used

**Japanese:**
[`espnet/kan-bayashi_jsut_fastspeech2`](https://huggingface.co/espnet/kan-bayashi_jsut_fastspeech2)

**English:**
[`espnet/kan-bayashi_ljspeech_fastspeech2`](https://huggingface.co/espnet/kan-bayashi_ljspeech_fastspeech2)

---

### 🈶 Japanese TTS

We use [**OpenJTalk**](https://github.com/r9y9/open_jtalk) to extract Japanese phonemes from input text. These phonemes are then used as input for the FastSpeech2 model.

---

### 🇺🇸 English TTS

For English, we convert graphemes to phonemes using the [**CMU Pronouncing Dictionary**](https://raw.githubusercontent.com/nltk/nltk_data/gh-pages/packages/corpora/cmudict.zip). The phonemes are then used as input for FastSpeech2.

---

### 🔊 Naturalness via HiFi-GAN

To improve naturalness, the mel-spectrogram output from FastSpeech2 is passed to HiFi-GAN to synthesize waveform audio.

---

### 📦 Dependencies

This project relies on the following external libraries and tools:

* **[OpenJTalkForiOS](https://github.com/yasuohasegawa/OpenJTalkForiOS)**
  Used for extracting Japanese phonemes from input text.
  Follow the installation instructions in the repo to integrate it into your Xcode project.

---

### ⚠️ Device Compatibility

* ❌ **Xcode Simulator is not supported.**
* ✅ **Tested only on iPhone 15 Pro.**
* Other devices are untested.

---

### ⚠️ Disclaimer

This project is provided as-is.
Please use and test **at your own risk** — we do not provide support.

---

## 📄 License

This project is licensed under the [Apache License 2.0](LICENSE).

The models and code are based on:

- [ESPnet](https://github.com/espnet/espnet)
- [espnet/kan-bayashi_jsut_fastspeech2](https://huggingface.co/espnet/kan-bayashi_jsut_fastspeech2)
- [espnet/kan-bayashi_ljspeech_fastspeech2](https://huggingface.co/espnet/kan-bayashi_ljspeech_fastspeech2)
- [HiFi-GAN](https://github.com/jik876/hifi-gan)

Modifications include conversion to Core ML format and integration with iOS.

---
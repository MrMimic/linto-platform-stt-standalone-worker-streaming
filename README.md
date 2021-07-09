# linto-platform-stt-standalone-worker-streaming

### InnoLab changes

This forks use Linto, vosk and Kaldi to provide a Dockerised STT service compile with Cuda.

### Build

Download a model: https://alphacephei.com/vosk/models

Check for your GPU architecture tag: https://arnon.dk/matching-sm-architectures-arch-and-gencode-for-various-nvidia-cards/

Provide the path to the unzipped model folder and your GPU architecture tag in .env file.

Run docker compose:

    docker-compose up



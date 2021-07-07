# linto-platform-stt-standalone-worker-streaming

### Innolab build

Preparet he environment (download models, etc)

    bash prepare.sh

Build submodules:

    git submodule update --init

Then, the docker image build has been modified to use Cuda flag with Tesla M60 GPU.

    docker build -t innolab/linto-stt-streaming-cuda:0.0.1 .


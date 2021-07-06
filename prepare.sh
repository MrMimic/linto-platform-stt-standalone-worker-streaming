#!/usr/bin/env bash

mkdir models
cd models || exit 1

# Download both language and accoustic model
mkdir tmp
cd tmp || exit 1
wget https://dl.linto.ai/downloads/model-distribution/decoding-graphs/LVCSR/fr-FR/decoding_graph_fr-FR_Big_v2.2.0.zip
wget https://dl.linto.ai/downloads/model-distribution/acoustic-models/fr-FR/linSTT_AM_fr-FR_v2.2.0.zip

# Unzip them
unzip decoding_graph_fr-FR_Big_v2.2.0.zip -d ../language-model/
unzip linSTT_AM_fr-FR_v2.2.0.zip -d ../acoustic-model/
cd ../
rm -rf tmp
cd ../
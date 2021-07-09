#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import argparse
# import numpy
import asyncio
import json

import websockets
from vosk import KaldiRecognizer, Model

from tools import WorkerStreaming

# Get arguments
parser = argparse.ArgumentParser(description="Websocket-based STT")
parser.add_argument("-m", "--model", help="Path to the pretrained models", required=True)
parser.add_argument("-p", "--port", help="The port for the servbice to be used", required=True)
arguments = vars(parser.parse_args())

# create WorkerStreaming object
worker = WorkerStreaming(am_path=arguments["model"],
                         lm_path=arguments["model"],
                         config_files=arguments["model"],
                         port=arguments["port"])

# Load ASR models (acoustic model and decoding graph)
worker.log.info("Load acoustic model and decoding graph")
model = Model(arguments["model"])
spkModel = None


# Decode chunk audio
def process_chunk(rec, message):
    if message == "{'eof' : 1}":
        return rec.FinalResult(), True
    elif rec.AcceptWaveform(message):
        return rec.Result(), False
    else:
        return rec.PartialResult(), False


# Recognizer
async def recognize(websocket, path):
    rec = None
    audio = b""
    sample_rate = model.GetSampleFrequecy()
    metadata = worker.METADATA

    while True:
        try:
            data = await websocket.recv()

            # Load configuration if provided
            if isinstance(data, str) and "config" in data:
                jobj = json.loads(data)["config"]
                if "sample_rate" in jobj:
                    sample_rate = float(jobj["sample_rate"])
                if "metadata" in jobj:
                    metadata = bool(jobj["metadata"])
                continue

            # Create the recognizer, word list is temporary disabled since not every model supports it
            if not rec:
                rec = KaldiRecognizer(model, spkModel, sample_rate, worker.ONLINE)

            if not isinstance(data, str):
                audio = audio + data

            response, stop = process_chunk(rec, data)
            await websocket.send(response)
            if stop:
                if metadata:
                    obj = rec.GetMetadata()
                    data = json.loads(obj)
                    response = worker.process_metadata(data, audio)
                    await websocket.send(response)
                break
        except Exception as e:
            break


if __name__ == "__main__":
    worker.log.info("Server is listening on port " + str(worker.SERVICE_PORT))
    start_server = websockets.serve(recognize, "0.0.0.0", worker.SERVICE_PORT)

    asyncio.get_event_loop().run_until_complete(start_server)
    asyncio.get_event_loop().run_forever()

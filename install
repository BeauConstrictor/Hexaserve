#!/bin/env sh

touch logs/gemini.txt
touch logs/runner.txt

echo "Hello, world!" > content/index.gmi

echo "Create an SSL certificate for your new server:"

openssl req -x509 -nodes -newkey rsa:4096 \
    -keyout "./ssl/key.pem" \
    -out "./ssl/cert.pem" \
    -days 36500

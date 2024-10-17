# Pasture 
A Simple Pastebin written in Nim

## Building Pasture

- To build this project you need a handy Nim Compiler.

Follow the [documentation](https://nim-lang.org/install.html) to learn how to install Nim on your machine.

- Clone this repository

```sh
git clone https://github.com/acmpesuecc/pasture --depth 1
cd pasture
```

- Build the project using Nimble
```sh
nimble build
```

## Usage

Just send the file as a `POST` request to the server!

Using [httpie](https://httpie.io/)

```sh
http --form POST localhost:8000 file@file.txt
```

Using [curl](https://curl.se/)
```sh
curl -F curl -F file=@file.txt http://localhost:8000
```

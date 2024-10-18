import std/[private/osdirs, oids, asynchttpserver, asyncdispatch, tables, strutils]

# ANSI color methods for terminal output
proc green*(s: string): string = "\e[32m" & s & "\e[0m"
proc grey*(s: string): string = "\e[90m" & s & "\e[0m"
proc yellow*(s: string): string = "\e[33m" & s & "\e[0m"
proc red*(s: string): string = "\e[31m" & s & "\e[0m"


proc logToFile(message: string) =
    let logFile = open("pasture.log", fmAppend)
    logFile.write(message & "\n")
    logFile.close()

proc logInfo(message: string) =
    let regularMessage = "[INFO] " & message
    let logMessage = "[INFO] ".grey & message
    echo logMessage
    logToFile(regularMessage)

proc logSuccess(message: string) =
    let regularMessage = "[SUCCESS] " & message
    let logMessage = "[SUCCESS] ".green & message
    echo logMessage
    logToFile(regularMessage)

proc logWarning(message: string) =
    let regularMessage = "[WARNING] " & message
    let logMessage = "[WARNING] ".yellow & message
    echo logMessage
    logToFile(regularMessage)

proc logError(message: string) =
    let regularMessage = "[ERROR] " & message
    let logMessage = "[ERROR] ".red & message
    echo logMessage
    logToFile(regularMessage)

proc handleGET(req: Request) {.async.} =
    let path = req.url.path
    logInfo("Handling GET request for path: " & path)
    if path == "/":
        await req.respond(Http200, "path: /")
        logSuccess("Responded with root path content")
    else:
        let hash = path[1..^1]
        try:
            let file = readFile("pasture/" & hash)
            logSuccess("File found: " & hash)
            await req.respond(Http200, file)
        except IOError:
            logError("File not found: " & hash)
            await req.respond(Http404, "File not found")

proc parseMultipartFormData(req: Request): Table[string, string] =
    var formData = initTable[string, string]()
    var contentType, boundary, body: string
    var inHeader = true

    let headers = req.headers["content-type"]
    let strheader = toString(headers)
    let spl = strheader.split(';')
    contentType = spl[0]

    logInfo("Parsing multipart/form-data")

    if contentType == "multipart/form-data":
        let data = req.body.splitLines()
        boundary = data[0]

        for line in data[1..^2]:
            if line.startsWith(boundary):
                inHeader = true
                continue

            if inHeader:
                if line == "\r\n" or line == "":
                    inHeader = false
                continue

            body.add(line & '\n')

            let linSplit = line.split(';')
            for part in linSplit:
                let content = part.split('=')
                let meta = part.split(':')
                if content.len > 1:
                    formData[content[0]] = content[1]
                if meta.len > 1:
                    formData[meta[0]] = meta[1]

        formData["body"] = body

    logSuccess("Multipart data parsed successfully")
    return formData

proc handlePOST(req: Request) {.async.} =
    let data = parseMultipartFormData(req)
    if data["body"] == "":
        logWarning("Received empty body in POST request")
        await req.respond(Http200, "File has no body. Nothing written to pasture")
        return
    let hash = genOid()
    writeFile("pasture/" & $hash, data["body"].strip())
    logSuccess("File saved with hash: " & $hash)
    await req.respond(Http200, "File saved. Hash: " & $hash & $'\n')

proc reqHandler(req: Request) {.async.} =
    logInfo("Received request: " & $req.reqMethod & " " & req.url.path)
    case req.reqMethod:
    of HttpMethod.HttpGet:
        await handleGET(req)
    of HttpPost:
        await handlePOST(req)
    else:
        logWarning("Unhandled request method: " & $req.reqMethod)
        discard

proc main() {.async.} =

    let server = newAsyncHttpServer()
    logInfo("Starting server on port 8008...")
    await serve(server, Port(8008), reqHandler)

when isMainModule:
    waitFor main()

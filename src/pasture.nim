import std/[private/osdirs, oids, asynchttpserver, asyncdispatch, tables, strutils, times]

# Add a type to store pastes with expiration info
type
    Paste = object
        content: string
        expiration: Time
        id: string

var pastes = initTable[string, Paste]()

# Modify the parseMultipartFormData to extract 'expire' if present
proc parseMultipartFormData(req: Request): Table[string, string] =
    var formData = initTable[string, string]()
    var contentType: string = ""
    var boundary: string = ""
    var str: string = ""
    var headers = req.headers["content-type"]
    var strheader = toString(headers)
    var spl = strheader.split(';')
    var inHeader = true
    contentType = spl[0]
    if contentType == "multipart/form-data":
        var data = req.body.splitLines()
        boundary = data[0]
        var body: string
        for i in data[1..^1]:
            if i == boundary & "--":
                break
            if i == "":
                inHeader = not inHeader
                continue
            if i.startsWith("{:}"):
                return formData
            if not inHeader:
                body = body & i & '\n'
                continue
            var linSplit = i.split(';')
            for j in linSplit:
                let content = j.split('=')
                let meta = j.split(':')
                if content.len > 1:
                    formData[content[0]] = content[1]
                if meta.len > 1:
                    formData[meta[0]] = meta[1]
        formData["body"] = body
    return formData

# Modify the handlePOST procedure to accept and process 'expire' parameter
proc handlePOST(req: Request) {.async.} =  
    let data = parseMultipartFormData(req)
    if data["body"] == "":
        await req.respond(Http200, "File has no body. Nothing written to pasture")
        return

    let expire = data.getOrDefault("expire", "24h")  # Default to 24 hours if not provided
    let expirationDuration = parseDuration(expire)
    let expirationTime = now() + expirationDuration

    let hash = genOid()
    let paste = Paste(content: data["body"], expiration: expirationTime, id: hash)
    pastes[hash] = paste

    writeFile("pasture/" & $hash, data["body"])
    await req.respond(Http200, "File saved. Hash: " & hash & $'\n')

# Check and delete expired pastes
proc checkExpiredPastes() {.async.} =
    while true:
        let currentTime = now()
        for id, paste in pastes.pairs:
            if paste.expiration < currentTime:
                echo "Deleting expired paste: ", id
                removeFile("pasture/" & id)
                pastes.del(id)
        await sleepAsync(60 * 1000)  # Check every minute

proc reqHandler(req: Request) {.async.} = 
    case req.reqMethod:
    of HttpMethod.HttpGet:
        echo req.url.path
    of HttpPost:
        echo "POST"
        await handlePOST(req)
    else: discard

proc main() {.async.}= 
    discard existsOrCreateDir("pasture")
    let server = newAsyncHttpServer()
    await serve(server, Port(8008), reqHandler)

when isMainModule:
    waitFor main()
    waitFor checkExpiredPastes()

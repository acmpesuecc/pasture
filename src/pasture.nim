import std/[private/osdirs, oids, asynchttpserver, asyncdispatch, tables, strutils, times]

proc parseMultipartFormData(req: Request): Table[string, string] =
    var formData = initTable[string, string]()
    var contentType: string = ""
    var boundary: string = ""
    
    let headers = req.headers["content-type"]
    let strheader = toString(headers)
    let spl = strheader.split(';')
    
    if spl.len > 1:
        contentType = spl[0].strip()
        if contentType == "multipart/form-data":
            boundary = "--" & spl[1].strip().split('=')[1]
            let data = req.body.splitLines()
            
            for i in data:
                if i == boundary & "--":
                    break
                if i == "" or i.startsWith(boundary):
                    continue
                if i.startsWith("{:}"):
                    return formData
                
                let linSplit = i.split(';')
                for j in linSplit:
                    let content = j.split('=')
                    if content.len > 1:
                        formData[content[0].strip()] = content[1].strip().replace("\"", "")
    
    return formData

proc deleteFileAfterDelay(filePath: string, duration: TimeSpan) {.async.} =
    await sleep(duration)
    try:
        removeFile(filePath)
        echo "Deleted file: ", filePath
    except OSError as e:
        echo "Error deleting file: ", e.msg

proc handlePOST(req: Request) {.async.} =  
    let data = parseMultipartFormData(req)
    if data["file"] == "":
        await req.respond(Http200, "File has no body. Nothing written to pasture")
        return

    let hash = genOid()
    let filePath = "pasture/" & $hash
    writeFile(filePath, data["file"])
    
    if data["expire"] != "":
        let expireValue = data["expire"]
        let duration = parseDuration(expireValue)
        if duration != TimeSpan(0):
            asyncCheck deleteFileAfterDelay(filePath, duration)
            req.respond(Http200, "File saved with expiry. Hash: " & $hash & ", will be deleted in: " & expireValue)
            return

    req.respond(Http200, "File saved. Hash: " & $hash & "\n")

proc parseDuration(expire: string): TimeSpan =
    if expire.endsWith("h"):
        return parseInt(expire.substr(0, expire.len - 1)) * 3600.seconds
    elif expire.endsWith("m"):
        return parseInt(expire.substr(0, expire.len - 1)) * 60.seconds
    elif expire.endsWith("s"):
        return parseInt(expire.substr(0, expire.len - 1)).seconds
    else:
        echo "Invalid expiry duration. Expected format: <number><s|m|h>"
        return TimeSpan(0)

proc reqHandler(req: Request) {.async.} = 
    case req.reqMethod:
    of HttpMethod.HttpGet:
        echo req.url.path
        # handleGET()
    of HttpMethod.HttpPost:
        echo "POST"
        await handlePOST(req)
    else: discard

proc main() {.async.} =
    discard existsOrCreateDir("pasture")
    let server = newAsyncHttpServer()
    await serve(server, Port(8008), reqHandler)

when isMainModule:
    waitFor main()

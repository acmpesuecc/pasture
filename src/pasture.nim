import std/[private/osdirs,oids,asynchttpserver,asyncdispatch,tables,strutils]

# proc handleGET()

proc parseMultipartFormData(req: Request): Table[string, string] =
    var formData = initTable[string, string]()
    var contentType: string = ""
    var boundary: string = ""
    var str:string = ""
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
            var linSplit = i.split(';');
            for j in linSplit:
                let content = j.split('=')
                let meta = j.split(':')
                if content.len > 1:
                    formData[content[0]] = content[1]
                if meta.len > 1:
                    formData[meta[0]] = meta[1]
        formData["body"] = body
                


    return formData


proc handlePOST(req: Request) {.async.} =  
    let data = parseMultipartFormData(req)
    if data["body"] == "":
        await req.respond(Http200, "File has no body. Nothing written to pasture")
        return
    let hash = genOid()
    writeFile("pasture/" & $hash, data["body"])
    req.respond(Http200, "File saved. Hash:" & $hash & $'\n')
    
    

proc reqHandler(req: Request) {.async.} = 
    case req.reqMethod:
    of HttpMethod.HttpGet:
        echo req.url.path
        # handleGET()
    of HttpPost:
        echo "POST"
        await handlePOST(req)
    else: discard

proc main() {.async.}=
    discard existsOrCreateDir("pasture")
    let server = newAsyncHttpServer()
    await serve(server, Port(8008),reqHandler)

when isMainModule:
    waitFor main()

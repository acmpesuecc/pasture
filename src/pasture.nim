import std/[hashes,asynchttpserver,asyncdispatch,tables,strutils]
type
  Something = object
    foo: int
    bar: string

proc hash(x: Something): Hash =
  ## Computes a Hash from `x`.
  var h: Hash = 0
  h = h !& hash(x.foo)
  h = h !& hash(x.bar)
  result = !$h

var x = Something(foo: 20 ,bar:"jackson")
echo hash(x)

# proc handleGET()


proc parseMultipartFormData(req: Request): Table[string, string] =
    var formData = initTable[string, string]()
    var contentType: string = ""
    var boundary: string = ""

    for part in req.headers["content-type"]:
        if part.strip().startswith("multipart/form-data"):
            let parts = part.split(";")
            for p in parts:
                if p.strip().startswith("boundary="):
                    boundary = p.strip().split("boundary=")[1].strip()
                    break
            contentType = part.strip()
            break

    if contentType == "multipart/form-data":
        let bodyStream = newFileStream(stdin.handle, fmReadable)
        bodyStream.rewind()

        var boundaryFound = false
        var boundaryStart: int

        while not bodyStream.atEnd:
            let line = bodyStream.readLine().strip()
            if line == "--" & boundary:
                boundaryFound = true
            elif line == "--" & boundary & "--":
                break
            elif boundaryFound:
                if line.len > 0:
                    var header: string
                    var headerValue: string
                    var fieldName: string

                    let fieldData = line.split(": ")
                    if fieldData.len > 1:
                        header = fieldData[0]
                        headerValue = fieldData[1]
                    else:
                        fieldName = line.split("=")[1].split(";")[0].strip().strip("\"")
                        header = line.split("=")[0].strip()

                        let fieldData = headerValue.split(";")
                        headerValue = fieldData[0].strip()
                        
                    formData[fieldName] = headerValue

    return formData

proc handlePOST(req: Request) {.async.} =  
    echo parseMultipartFormData(req)

proc reqHandler(req: Request) {.async.} = 
    case req.reqMethod:
    of HttpMethod.HttpGet:
        echo "GET"
        # handleGET()
    of HttpPost:
        await handlePOST(req)
    else: discard

proc main() {.async.}=
    let server = newAsyncHttpServer()
    server.listen(Port(8008))
    echo("HTTP Server running on :",$(8008))
    while true:
        if server.shouldAcceptRequest():
            await server.acceptRequest(reqHandler)

when isMainModule:
    waitFor main()

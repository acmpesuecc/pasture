import std/[hashes,asynchttpserver,asyncdispatch,tables,strutils,sequtils]
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
    var str:string = ""
    var headers = req.headers["content-type"]
    var strheader = toString(headers)
    var spl = strheader.split(';')
    echo spl
    echo req.body


    echo contentType

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

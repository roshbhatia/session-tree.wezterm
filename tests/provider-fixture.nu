def main [mode: string] {
    let request = open --raw /dev/stdin | from json
    if $mode == missing {
        {version: 'provider/v1', kind: event, requestId: $request.requestId} | to json -r
    } else {
        {
            version: 'provider/v1'
            kind: result
            requestId: (if $mode == unrelated { 'other' } else { $request.requestId })
            status: ok
            output: $request.input
        } | to json -r
    }
}

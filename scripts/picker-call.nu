export def call [manifest_path: path, capability: string, item?: string] {
    let manifest = open $manifest_path
    if $manifest.version? != 'provider/v1' or $capability not-in ($manifest.actions | columns) {
        error make {msg: $'provider does not support ($capability)'}
    }
    let input = if $item == null {
        {}
    } else if $capability == 'picker.create' {
        {name: $item}
    } else if $capability == 'picker.rename' {
        $item | from json
    } else {
        {id: $item}
    }
    let request = {
        version: 'provider/v1'
        kind: request
        requestId: (random uuid)
        capability: $capability
        input: $input
    }
    let argv = $manifest.command | append (
        $manifest.actions
        | get $capability
        | get -o argv
        | default []
    )
    let deadline = $manifest.actions | get $capability | get timeout? | default '5s'
    if $deadline !~ '^([1-9]|[12][0-9]|30)s$' {
        error make {msg: 'provider action timeout must be between 1s and 30s'}
    }
    let result = ($request | to json -r) + "\n" | ^timeout $deadline ...$argv | complete
    if $result.exit_code != 0 {
        error make {
            msg: (
                if ($result.stderr | str trim) != '' {
                    $result.stderr | str trim
                } else {
                    $'provider exited ($result.exit_code)'
                }
            )
        }
    }
    mut answer: any = null
    for line in ($result.stdout | lines | where {|line| $line != ''}) {
        let frame = $line | from json
        if $frame.version? != 'provider/v1' or $frame.requestId? != $request.requestId {
            error make {msg: 'provider returned an unrelated frame'}
        }
        if $answer != null { error make {msg: 'provider wrote after its result'} }
        if $frame.kind? == result {
            $answer = $frame
        } else if $frame.kind? != event {
            error make {msg: 'provider returned an invalid frame'}
        }
    }
    if $answer == null or $answer.status? != ok {
        error make {
            msg: ($answer.message? | default 'provider returned no result')
        }
    }
    $answer.output
}

export def catalog [manifest_path: path] {
    let manifest = open $manifest_path
    let results = [picker.describe picker.list] | par-each {|capability|
        {capability: $capability, output: (call $manifest_path $capability)}
    }
    {
        descriptor: (
            $results
            | where capability == picker.describe
            | first
            | get output
        )
        listed: (
            $results
            | where capability == picker.list
            | first
            | get output
        )
        can_create: ('picker.create' in ($manifest.actions | columns))
        can_rename: ('picker.rename' in ($manifest.actions | columns))
        can_delete: ('picker.delete' in ($manifest.actions | columns))
    }
}

def main [--catalog, ...arguments: string] {
    if $catalog {
        let manifest = $arguments.0
        let destination = $arguments.1
        let result = try {
            {
                ok: true
                catalog: (catalog $manifest)
            }
        } catch {|failure| {ok: false, error: $failure.msg} }
        let temporary = ^mktemp ($destination + '.XXXXXX') | str trim
        try {
            $result | to json -r | save --force $temporary
            if ($destination | path exists) {
                mv --force $temporary $destination
            } else {
                rm $temporary
            }
        } catch {|failure|
            if ($temporary | path exists) { rm $temporary }
            error make $failure
        }
    } else {
        call $arguments.0 $arguments.1 ($arguments.2? | default null) | to json -r
    }
}

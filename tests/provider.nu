use std/assert

def main [runner: path, fixture: path] {
    let root = mktemp -d
    let manifest = $root | path join provider.json
    let nu_binary = $nu.current-exe
    let definition = {
        version: 'provider/v1'
        command: [$nu_binary '--no-config-file' $fixture ok]
        actions: {
            'picker.describe': {}
            'picker.list': {}
            'picker.open': {}
            'picker.create': {}
            'picker.rename': {}
            'picker.delete': {}
        }
    }
    try {
        $definition | save $manifest
        let name = 'name with spaces; $HOME'
        let created = ^$nu_binary --no-config-file $runner $manifest picker.create $name | from json
        assert ($created == {name: $name})
        let renamed = ^$nu_binary --no-config-file $runner $manifest picker.rename ('{"id":"old","name":"new"}') | from json
        assert ($renamed == {id: old, name: new})
        let deleted = ^$nu_binary --no-config-file $runner $manifest picker.delete old | from json
        assert ($deleted == {id: old})
        let output = $root | path join result.json
        touch $output
        ^$nu_binary --no-config-file $runner --catalog $manifest $output
        let result = open $output
        assert $result.ok
        assert $result.catalog.can_create
        assert $result.catalog.can_rename
        assert $result.catalog.can_delete
        assert ((ls -l $output | first | get mode) == 'rw-------')
        rm $output
        ^$nu_binary --no-config-file $runner --catalog $manifest $output
        assert (not ($output | path exists)) 'cancelled catalog was recreated'
        for mode in [unrelated missing] {
            $definition | update command [$nu_binary '--no-config-file' $fixture $mode] | save --force $manifest
            let rejected = ^$nu_binary --no-config-file $runner $manifest picker.list | complete
            assert ($rejected.exit_code != 0)
            assert (
                $rejected.stderr
                | str contains (if $mode == unrelated { 'unrelated frame' } else { 'no result' })
            ) $rejected.stderr
        }
        $definition | update actions {} | save --force $manifest
        let rejected = ^$nu_binary --no-config-file $runner $manifest picker.create name | complete
        assert ($rejected.exit_code != 0)
    } catch {|failure|
        rm --recursive $root
        error make $failure
    }
    rm --recursive $root
    print 'Provider protocol, lifecycle capabilities, cancellation, and correlation passed'
}

#!/bin/bash

SCRIPT=$(readlink -f "$0")
SCRIPTPATH=$(dirname "$SCRIPT")

function build_ipxe() {
    local embedded_file="chain.ipxe" # the file to embed in built artifact
    pushd ${SCRIPTPATH}/ipxe/src
    echo "Building undionly.kpxe"
    make bin/undionly.kpxe EMBED=${SCRIPTPATH}/$embedded_file
    
    popd
    echo "Moving undionly.kpxe to ./bin/"
    mv ipxe/src/bin/undionly.kpxe ./bin/
}


# TODO: case statement for multiple builds?
build_ipxe
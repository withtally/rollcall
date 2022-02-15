#!bin/sh

set -eo pipefail

if [[ ${DEBUG} ]]; then
    set -x
fi

deploy() {
    NAME=$1
    PASSTHROUGH=$2
    ARGS=${@:3}

    forge create $NAME $ARGS $PASSTHROUGH |
    while IFS= read -r line
    do
        echo "$line" >&2
        if echo "$line" | grep -q 'Deployed to:'; then
            echo $(echo "$line" | sed 's/^.*: //')
        fi
    done
}

ensure() {
    echo "${!1}"
    if [ -z "${!1}" ]; then
        echo "
Variable \$$1 is not set. Did you miss a step?
"
        exit 1
    fi
}
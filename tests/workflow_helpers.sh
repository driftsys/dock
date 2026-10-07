#!/usr/bin/env bash
# Evaluate the matrix lookups and image predicates used by the workflow steps.

workflow_matrix_value() {
    local template="$1" key="$2" value="$3" expression
    case "$template" in
        "\${{"*'}}')
            expression="${template#"\${{"}"
            expression="${expression%'}}'}"
            expression="${expression//matrix./.matrix.}"
            expression="${expression//\'/\"}"
            expression="${expression//'||'/'//'}"
            jq -nr --arg key "$key" --arg value "$value" \
              '{matrix: {($key): $value}} | ('"$expression"')'
            ;;
        *) printf '%s\n' "$template" ;;
    esac
}

workflow_selects_image() {
    local condition="$1" image="$2"
    condition="${condition#"\${{"}"
    condition="${condition%'}}'}"
    condition="${condition//matrix.image/\$image}"
    condition="${condition//\'/\"}"
    condition="${condition//'||'/'or'}"
    condition="${condition//'&&'/'and'}"
    jq -ne --arg image "$image" "$condition" >/dev/null
}

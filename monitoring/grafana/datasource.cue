package grafana

import (
	"alpha.dagger.io/dagger"
	"alpha.dagger.io/dagger/op"
    "alpha.dagger.io/alpine"
)

#CreateLokiDataSource: {
    // Grafana Url
    url: string

    // Grafana username
    username: string

    // Grafana password
    password: string

    // Wait Grafana installed
    waitGrafana: dagger.#Artifact

    // Wait Loki installed
    waitLoki: dagger.#Artifact

    #up: [
        op.#Load & {
            from: alpine.#Image & {
                package: bash:         true
                package: curl:         true
                package: jq: true
                package: sed: true
            }
        },

        op.#Exec & {
            dir: "/root"
            env: {
                URL:    url
                NAME: username
                PASSWORD: password
            }
            mount: "/waitgrafana": from: waitGrafana
            mount: "/waitloki": from: waitLoki
            args: [
                "/bin/bash",
                "--noprofile",
                "--norc",
                "-eo",
                "pipefail",
                "-c",
                #"""
                PASSWORD=$(echo $PASSWORD | xargs)
                url=$NAME:$PASSWORD@$URL
                # check datasource
                source=( $(curl $url/api/datasources | jq -r '.[] | .type') )
                for i in ${source[@]}; do
                    if [ "$i" == "loki" ]; then
                        echo 'loki data source exist'
                        exit 0
                    fi
                done

                # 1. add data source
                curl $url/api/datasources \
                -H 'content-type: application/json' \
                --data-raw '{"name":"Loki","type":"loki","access":"proxy","isDefault":false}' \
                --compressed | jq '.datasource' > /datasource.json
                
                cat /datasource.json

                # 2. get data source id
                id=$(cat /datasource.json | jq --raw-output '.id')

                # 3. edit json file .url
                tmp=$(mktemp)
                loki_url=http://loki.logging:3100
                jq --arg a "$loki_url" '.url = $a' /datasource.json > "$tmp" && mv "$tmp" /datasource.json

                cat /datasource.json

                # 4. put data source config
                curl $url/api/datasources/$id \
                -X 'PUT' \
                -H 'content-type: application/json' \
                -d @/datasource.json
                """#,
            ]
            always: true
        },
    ]
}
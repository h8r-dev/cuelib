package gitlab

import (
	"alpha.dagger.io/dagger"
	"alpha.dagger.io/dagger/op"
    "alpha.dagger.io/os"
    "alpha.dagger.io/docker"
)

// Init git repo
#InitRepo: {
    // Infra check success
    checkInfra: dagger.#Input & {string}

	// Application name, will be set as repo name
	applicationName: dagger.#Input & {string}

	// Gitlab personal access token, and will also use to pull ghcr.io image
	accessToken: dagger.#Input & {dagger.#Secret}

	// Gitlab organization name or username, currently only supported username
	organization: dagger.#Input & {string}

    // Source code path, for example code/go-gin
	sourceCodePath: dagger.#Input & {string}

	// TODO default repoDir path, now you can set "." with dagger dir type
	sourceCodeDir: dagger.#Artifact @dagger(input)

    // Helm chart
    isHelmChart: dagger.#Input & {string} | *"false"

    // Git URL
	gitUrl: {
		string

		#up: [
			op.#Load & {
                // from: alpine.#Image & {
				// 	package: bash:         true
				// 	package: jq:           true
				// 	package: git:          true
				// 	package: curl:         true
				// 	package: sed:          true
				// 	package: "github-cli": true
				// }
                from: os.#Container & {
                    image: docker.#Pull & {
                        from: "ubuntu:latest"
                    }
                    shell: path: "/bin/bash"
                    setup: [
                        "apt-get update",
                        "apt-get install jq -y",
                        "apt-get install git -y",
                        "apt-get install curl -y",
                        "apt-get install wget -y",
                        "apt-get clean"
                    ]
                }
			},

			op.#Exec & {
				mount: "/run/secrets/gitlab": secret: accessToken
				mount: "/root": from:                sourceCodeDir
				dir: "/root"
				env: {
					REPO_NAME:    applicationName
					ORGANIZATION: organization
                    SOURCECODEPATH: sourceCodePath
                    ISHELMCHART: isHelmChart
				}
				args: [
                    "/bin/bash",
                    "--noprofile",
                    "--norc",
                    "-eo",
                    "pipefail",
                    "-c",
                        #"""
                        gitlab_id=$(curl -sH --header "Authorization: Bearer $(cat /run/secrets/gitlab)" "https://gitlab.com/api/v4/users?username=$ORGANIZATION" | jq '.[0] | .id')
                        create=$(curl -sH -XPOST --header "Authorization: Bearer $(cat /run/secrets/gitlab)" "https://gitlab.com/api/v4/projects" -d "name=$REPO_NAME&visibility=public")
                        id=$(echo $create | jq '.id')
                        if [ $id != "null" ]
                        then
                            echo "Succeed to create repo $REPO_NAME" > /output.txt
                        else
                            echo "Failed to create repo $REPO_NAME" > /output.txt
                        fi
                        """#,
				]
				always: true
			},

			op.#Export & {
				source: "/output.txt"
				format: "string"
			},
		]
	} @dagger(output)
}

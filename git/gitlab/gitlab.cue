package gitlab

import (
	"alpha.dagger.io/dagger"
	"alpha.dagger.io/dagger/op"
	"alpha.dagger.io/os"
	"alpha.dagger.io/docker"
)

// TODO split this repo into parts

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

	// Gitlab require user's email address for push 
	gitEmail: dagger.#Input & {string}

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
				//  package: bash:         true
				//  package: jq:           true
				//  package: git:          true
				//  package: curl:         true
				//  package: sed:          true
				//  package: "github-cli": true
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
						"apt-get clean",
					]
				}
			},

			op.#Exec & {
				mount: "/run/secrets/gitlab": secret: accessToken
				mount: "/root": from:                 sourceCodeDir
				dir: "/root"
				env: {
					REPO_NAME:      applicationName
					ORGANIZATION:   organization
					SOURCECODEPATH: sourceCodePath
					ISHELMCHART:    isHelmChart
					GIT_EMAIL:      gitEmail
				}
				args: [
					"/bin/bash",
					"--noprofile",
					"--norc",
					"-eo",
					"pipefail",
					"-c",
					#"""
						GITLAB_ID=$(curl -sH --header "Authorization: Bearer $(cat /run/secrets/gitlab)" "https://gitlab.com/api/v4/users?username=$ORGANIZATION" | jq '.[0] | .id')
						GITLAB_USERNAME=$(curl -sH --header "Authorization: Bearer $(cat /run/secrets/gitlab)" "https://gitlab.com/api/v4/users?username=$ORGANIZATION" | jq '.[0] | .username')
						CREATE_INFO=$(curl -sH -XPOST --header "Authorization: Bearer $(cat /run/secrets/gitlab)" "https://gitlab.com/api/v4/projects" -d "name=l$REPO_NAME&visibility=public")
						REPO_ID=$(echo $CREATE_INFO | jq '.id')
						if [ $REPO_ID != "null" ]
						then
						    echo "Succeed to create repo $REPO_NAME" > /output.txt
						else
						    echo "Failed to create repo $REPO_NAME" > /output.txt
						    exit 0
						fi
						SSH_URL=$(echo $CREATE_INFO | jq .ssh_url_to_repo| sed 's/\"//g')
						git config --global user.name $GITLAB_USERNAME
						git config --global user.email $GIT_EMAIL
						cd $SOURCECODEPATH && git init
						git remote add origin $SSH_URL
						git add .
						git commit -m 'init repo'
						git branch -M main
						git push -u origin main
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

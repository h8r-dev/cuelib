package nocalhost

import (
	"alpha.dagger.io/dagger"
	"alpha.dagger.io/dagger/op"
    "alpha.dagger.io/os"
    "alpha.dagger.io/docker"
)

#LoginNocalhost: {
    // Wait Nocalhost install
    waitNocalhost: dagger.#Artifact

    // Nocalhost URL
    nocalhostURL: dagger.#Input & {string}

    adminUser: dagger.#Input & {string | *"admin@admin.com"}

    adminPwd: dagger.#Input & {string | *"123456"}

    #up: [
        op.#Load & {
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
            dir: "/"
            env: {
                URL: nocalhostURL
                USER: adminUser
                PASSWORD: adminPwd
            }
            args: [
                "/bin/bash",
                "--noprofile",
                "--norc",
                "-eo",
                "pipefail",
                "-c",
                #"""
                    until $(curl --output /dev/null --silent --head --fail $URL/health); do
                        printf 'nocalhost ready'
                        sleep 2
                    done
                    mkdir /output
                    curl --location --request POST $URL/v1/login \
                    --header "Content-Type: application/json" \
                    --data-raw '{"email":"'$USER'","password":"'$PASSWORD'"}' > /output/token.json
                    echo "$(jq '. += {"url": "'$URL'"}' /output/token.json)" > /output/token.json
                """#
            ]
            always: true
            mount: "/waitnocalhost": from: waitNocalhost
        },

        op.#Subdir & {
			dir: "/output"
		},
    ]
}

#CreateNocalhostTeam: {
    // Github team info
    githubMemberSource: dagger.#Artifact
    
    // Nocalhost login token
    nocalhostTokenSource: dagger.#Artifact

    // Wait Nocalhost install
    waitNocalhost: dagger.#Artifact

    #up: [
        op.#Load & {
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
            args: [
                "/bin/bash",
                "--noprofile",
                "--norc",
                "-eo",
                "pipefail",
                "-c",
                    #"""
                    NOCALHOST_URL=$(cat /nocalhost/token.json | jq .url | sed 's/\"//g')
                    echo $NOCALHOST_URL
                    until $(curl --output /dev/null --silent --head --fail $NOCALHOST_URL/health); do
                        printf 'nocalhost ready'
                        sleep 2
                    done
                    TOKEN=$(cat /nocalhost/token.json | jq .data.token | sed 's/\"//g')
                    jq -c '.[]' /github/member.json | while read i; do
                        user=$(echo $i | jq .login | sed 's/\"//g')
                        curl --location --request POST $NOCALHOST_URL/v1/users \
                        --header 'Authorization: Bearer '$TOKEN'' \
                        --header 'Content-Type: application/json' \
                        --data-raw '{"confirm_password":"123456","email":"'$user'@h8r.io","is_admin":0,"name":"'$user'","password":"123456","status":1}'
                    done
                    mkdir /done
                    echo 'OK' > /done/wait
                """#
            ]
            always: true
            mount: "/github": from: githubMemberSource
            mount: "/nocalhost": from: nocalhostTokenSource
            mount: "/waitnocalhost": from: waitNocalhost
        },

        op.#Subdir & {
            dir: "/done"
        },
    ]
}

#CreateNocalhostCluster: {
    // Nocalhost login token
    nocalhostTokenSource: dagger.#Artifact

    // Cluster kubeconfig
    myKubeconfig: dagger.#Input & {dagger.#Secret}

    // Wait Nocalhost install
    waitNocalhost: dagger.#Artifact

    #up: [
        op.#Load & {
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
            args: [
                "/bin/bash",
                "--noprofile",
                "--norc",
                "-eo",
                "pipefail",
                "-c",
                    #"""
                    kubeconfig=$(base64 -w0 /kubeconfig)
                    NOCALHOST_URL=$(cat /nocalhost/token.json | jq .url | sed 's/\"//g')
                    echo $NOCALHOST_URL
                    until $(curl --output /dev/null --silent --head --fail $NOCALHOST_URL/health); do
                        printf 'nocalhost ready'
                        sleep 2
                    done
                    TOKEN=$(cat /nocalhost/token.json | jq .data.token | sed 's/\"//g')
                    curl --location --request POST $NOCALHOST_URL/v1/cluster \
                    --header 'Authorization: Bearer '$TOKEN'' \
                    --header 'Content-Type: application/json' \
                    --data-raw '{"name":"initCluster","kubeconfig":"'$kubeconfig'"}'
                    mkdir /done
                    echo 'OK' > /done/wait
                """#
            ]
            if (myKubeconfig & dagger.#Secret) != _|_ {
                mount: "/kubeconfig": secret: myKubeconfig
            }
            always: true
            mount: "/nocalhost": from: nocalhostTokenSource
            mount: "/waitnocalhost": from: waitNocalhost
        },

        op.#Subdir & {
            dir: "/done"
        },
    ]
}

#CreateNocalhostApplication: {
    // Nocalhost login token
    nocalhostTokenSource: dagger.#Artifact

    // Application name
    applicationName: string

    // Git URL
    gitUrl: string

    // Source
    source: string | *"git"

    // Install type
    installType: string | *"helm_chart"

    // Wait Nocalhost install
    waitNocalhost: dagger.#Artifact

    do: {
        string

        #up: [
            op.#Load & {
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
                env: {
					APPNAME:    applicationName
					GITURL: gitUrl
                    SOURCE: source
                    INSTALL_TYPE: installType
				}
                args: [
                    "/bin/bash",
                    "--noprofile",
                    "--norc",
                    "-eo",
                    "pipefail",
                    "-c",
                        #"""
                        NOCALHOST_URL=$(cat /nocalhost/token.json | jq .url | sed 's/\"//g')
                        echo $NOCALHOST_URL
                        until $(curl --output /dev/null --silent --head --fail $NOCALHOST_URL/health); do
                            printf 'nocalhost ready'
                            sleep 2
                        done
                        TOKEN=$(cat /nocalhost/token.json | jq .data.token | sed 's/\"//g')
                        export GITURL=$(echo $GITURL | sed 's/ //g')
                        echo $GITURL
                        echo '{"context":"{\"application_url\":\"'$GITURL'\",\"application_name\":\"'$APPNAME'\",\"source\":\"'$SOURCE'\",\"install_type\":\"'$INSTALL_TYPE'\",\"resource_dir\":[]}","status":1}'
                        curl --location --request POST $NOCALHOST_URL/v1/application \
                        --header 'Authorization: Bearer '$TOKEN'' \
                        --header 'Content-Type: application/json' \
                        --data-raw '{"context":"{\"application_url\":\"'$GITURL'\",\"application_name\":\"'$APPNAME'\",\"source\":\"'$SOURCE'\",\"install_type\":\"'$INSTALL_TYPE'\",\"resource_dir\":[]}","status":1}'
                    """#
                ]
                always: true
                mount: "/nocalhost": from: nocalhostTokenSource
                mount: "/waitnocalhost": from: waitNocalhost
            },
        ]
    }
}

#CreateNocalhostDevSpace: {
    // Nocalhost login token
    nocalhostTokenSource: dagger.#Artifact

    // Wait user created
    waitUser: dagger.#Artifact

    // Wait cluster created
    waitCluster: dagger.#Artifact

    // Wait Nocalhost install
    waitNocalhost: dagger.#Artifact

    #up: [
        op.#Load & {
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
            args: [
                "/bin/bash",
                "--noprofile",
                "--norc",
                "-eo",
                "pipefail",
                "-c",
                    #"""
                    NOCALHOST_URL=$(cat /nocalhost/token.json | jq .url | sed 's/\"//g')
                    echo $NOCALHOST_URL
                    until $(curl --output /dev/null --silent --head --fail $NOCALHOST_URL/health); do
                        printf 'nocalhost ready'
                        sleep 2
                    done
                    TOKEN=$(cat /nocalhost/token.json | jq .data.token | sed 's/\"//g')
                    # Get Cluster
                    clusterID=$(curl -s --location --request GET $NOCALHOST_URL/v2/dev_space/cluster \
                    --header 'Authorization: Bearer '$TOKEN'' | jq '.data | .[0] | .id')
                    if [ "$clusterID" == "null"]; then
                        exit 0
                    fi
                    nocalhostUser=( $(curl -k --location --request GET $NOCALHOST_URL/v1/users \
                    --header 'Authorization: Bearer '$TOKEN'' | jq -r '.data | .[] | .id') )

                    nocalhostDevSpaceUser=( $(curl -k --location --request GET $NOCALHOST_URL/v2/dev_space \
                    --header 'Authorization: Bearer '$TOKEN'' | jq -r '.data | .[] | .user_id') )

                    # Find user to create devspace
                    for i in ${nocalhostDevSpaceUser[@]}
                    do
                    c=$(echo ${nocalhostUser[*]} | sed 's/\<'$i'\>//')
                    unset nocalhostUser
                    nocalhostUser=${c[@]}
                    done

                    namespaceArray=()
                    for i in ${nocalhostUser[@]}; do
                        namespaceArray[${#namespaceArray[@]}]=$(curl --location --request POST $NOCALHOST_URL/v1/dev_space \
                        --header 'Authorization: Bearer '$TOKEN'' \
                        --header 'Content-Type: application/json' \
                        --data-raw '{"cluster_id":'$clusterID',"cluster_admin":0,"user_id":'$i',"space_name":"","space_resource_limit":null}' | jq '.data | .namespace')
                    done
                    mkdir /output
                    printf '%s\n' "${namespaceArray[@]}" | jq -R . | jq -s . > /output/devNamespace.json
                """#
            ]
            always: true
            mount: "/nocalhost": from: nocalhostTokenSource
            mount: "/user": from: waitUser
            mount: "/cluster": from: waitCluster
            mount: "/waitnocalhost": from: waitNocalhost
        },

        op.#Subdir & {
            dir: "/output"
        },
    ]
}
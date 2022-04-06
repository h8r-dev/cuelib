# CUE

`Heighliner` `CUE Module`，用于构建云原生最佳实践，引入方法：
```
import "github.com/h8r-dev/cuelib"
```

# Package

`CUE Package` 按职责划分：

```
.
├── README.md
├── apm
│   ├── newrelic
│   └── skywalking
├── cd
│   ├── argocd
│   ├── fluxcd
│   └── tekton
├── ci
│   ├── github
│   ├── gitlab
│   ├── jenkins
│   └── tekton
├── cloud
│   ├── aliyun
│   ├── huawei
│   └── tencent
├── cue.mod
│   └── module.cue
├── cue.mods
├── deploy
│   ├── helm
│   ├── kubectl
│   └── kustomize
├── dev
│   └── nocalhost
├── framework
│   ├── gin
│   ├── react
│   └── vue
├── h8r
│   └── ingress
├── logging
├── monitoring
│   ├── datadog
│   ├── grafana
│   └── prometheus
├── network
│   └── ingress
├── package
│   ├── acr
│   ├── ghcr
│   ├── harbor
│   └── jfrog
├── scm
│   ├── bitbucket
│   ├── github
│   └── gitlab
├── tracing
│   ├── jaeger
│   └── zipkin
└── utils
    ├── base
    ├── fs
    └── random
```
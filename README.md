# CUE

`Heighliner` CUE Module，用于构建云原生最佳实践，引入方法：
```
import "github.com/h8r/cue"
```

# Package

包按职责划分：

```
├── alert                         // 报警
├── build                         // 构建
│   ├── github                    
│   ├── gitlab
│   ├── jenkins
│   └── tekton
├── cloud                         // 云厂商
│   ├── aliyun
│   ├── huawei
│   └── tencent
│       └── tke
│           └── tke.cue
├── cue.mod
│   └── module.cue
├── deploy                        // 部署
│   ├── argocd
│   ├── helm
│   │   └── helm.cue
│   └── kubectl
├── git                           // 代码仓库
│   ├── coding
│   ├── github
│   │   └── github.cue
│   └── gitlab
├── logs                          // 日志
├── monitoring                    // 监控
└── tracing                       // 分布式追踪
```
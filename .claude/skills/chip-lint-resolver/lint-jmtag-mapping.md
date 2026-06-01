# Lint Rule → JMTAG Mapping Reference

> Source: `work/jmp/lint规则.xlsx`
> Auto-generated: 2026-05-21

## JMTAG Execution Standards

| JMTAG | Execution Standard |
|-------|-------------------|
| JM_E0 | Mandatory fix: LLM analyzes RTL and produces modification proposal |
| JM_E1 | Mandatory fix: LLM analyzes RTL and produces modification proposal |
| JM_E2 | Mandatory fix: LLM analyzes RTL and produces modification proposal |
| JM_E3 | LLM checks if RTL has actual issue; if yes, fix; if no, generate waive |
| JM_Warning | LLM checks if RTL has actual issue; if yes, fix; if no, generate waive |
| JM_Info | LLM checks if RTL has actual issue; if yes, fix; if no, generate waive |
| JM_HARDEN | Ask user to confirm if HARDEN or boundary issue; then LLM analyzes RTL for fix or waive |

## Lint Rule → JMTAG Mapping (274 rules)

### JM_E0 (Mandatory Fix)

| Lint Rule | JMTAG |
|-----------|-------|
| badimplicitSM1 | JM_E0 |
| badimplicitSM4 | JM_E0 |
| bothedges | JM_E0 |
| ChkSensExprPar-ML | JM_E0 |
| CombLoop | JM_E0 |
| ConsCase | JM_E0 |
| CoveragePragma-ML | JM_E0 |
| DisallowXInCasez-ML | JM_E0 |
| DuplicateCaseLabel-ML | JM_E0 |
| IfOverlap-ML | JM_E0 |
| InferLatch | JM_E0 |
| LatchFeedback | JM_E0 |
| LoopBound | JM_E0 |
| MemConflict-ML | JM_E0 |
| mixedsenselist | JM_E0 |
| NoAssignX-ML | JM_E0 |
| NonWireSignal-ML | JM_E0 |
| NoStrengthInput-ML | JM_E0 |
| NoTimeOut | JM_E0 |
| NullPort-ML | JM_E0 |
| readclock | JM_E0 |
| sim_race02 | JM_E0 |
| STARC05-1.1.1.3 | JM_E0 |
| STARC05-1.1.1.5 | JM_E0 |
| STARC05-1.3.1.6 | JM_E0 |
| STARC05-1.3.1.7 | JM_E0 |
| STARC05-1.4.3.4 | JM_E0 |
| STARC05-1.4.3.6 | JM_E0 |
| STARC05-2.1.2.2 | JM_E0 |
| STARC05-2.1.2.4 | JM_E0 |
| STARC05-2.1.3.1 | JM_E0 |
| STARC05-2.1.3.2 | JM_E0 |
| STARC05-2.1.5.3 | JM_E0 |
| STARC05-2.1.6.5 | JM_E0 |
| STARC05-2.10.1.4a | JM_E0 |
| STARC05-2.10.1.6 | JM_E0 |
| STARC05-2.10.2.3 | JM_E0 |
| STARC05-2.10.3.2a | JM_E0 |
| STARC05-2.10.4.5 | JM_E0 |
| STARC05-2.11.3.1 | JM_E0 |
| STARC05-2.3.1.2c | JM_E0 |
| STARC05-2.3.1.6 | JM_E0 |
| STARC05-2.3.3.1 | JM_E0 |
| STARC05-2.3.3.2a | JM_E0 |
| STARC05-2.3.3.2b | JM_E0 |
| STARC05-2.3.4.2 | JM_E0 |
| STARC05-2.4.1.5 | JM_E0 |
| STARC05-2.5.1.2 | JM_E0 |
| STARC05-2.5.1.7 | JM_E0 |
| STARC05-2.5.1.9 | JM_E0 |
| STARC05-2.7.2.3 | JM_E0 |
| STARC05-2.7.4.3 | JM_E0 |
| STARC05-2.8.1.3 | JM_E0 |
| STARC05-2.9.1.2a | JM_E0 |
| STARC05-2.9.1.2b | JM_E0 |
| STARC05-2.9.1.2c | JM_E0 |
| STARC05-3.2.4.3 | JM_E0 |
| UndrivenOutPort-ML | JM_E0 |
| UndrivenOutTermNLoaded-ML | JM_E0 |
| W110 | JM_E0 |
| W116 | JM_E0 |
| W122 | JM_E0 |
| W123 | JM_E0 |
| W171 | JM_E0 |
| W182c | JM_E0 |
| W182g | JM_E0 |
| W182h | JM_E0 |
| W182k | JM_E0 |
| W182n | JM_E0 |
| W188 | JM_E0 |
| W19 | JM_E0 |
| W213 | JM_E0 |
| W224 | JM_E0 |
| W226 | JM_E0 |
| W239 | JM_E0 |
| W241 | JM_E0 |
| W245 | JM_E0 |
| W250 | JM_E0 |
| W287b | JM_E0 |
| W289 | JM_E0 |
| W294 | JM_E0 |
| W295 | JM_E0 |
| W309 | JM_E0 |
| W310 | JM_E0 |
| W313 | JM_E0 |
| W336 | JM_E0 |
| W337 | JM_E0 |
| W339a | JM_E0 |
| W352 | JM_E0 |
| W392 | JM_E0 |
| W395 | JM_E0 |
| W398 | JM_E0 |
| W414 | JM_E0 |
| W415 | JM_E0 |
| W415a | JM_E0 |
| W416 | JM_E0 |
| W421 | JM_E0 |
| W422 | JM_E0 |
| W423 | JM_E0 |
| W424 | JM_E0 |
| W425 | JM_E0 |
| W430 | JM_E0 |
| W442c | JM_E0 |
| W442f | JM_E0 |
| W450L | JM_E0 |
| W467 | JM_E0 |
| W468 | JM_E0 |
| W479 | JM_E0 |
| W480 | JM_E0 |
| W481a | JM_E0 |
| W481b | JM_E0 |
| W494 | JM_E0 |
| W495 | JM_E0 |
| W496a | JM_E0 |
| W496b | JM_E0 |
| W499 | JM_E0 |
| W504 | JM_E0 |
| W505 | JM_E0 |
| W546 | JM_E0 |
| W551 | JM_E0 |
| W561 | JM_E0 |
| W66 | JM_E0 |

### JM_E1 (Mandatory Fix)

| Lint Rule | JMTAG |
|-----------|-------|
| NoWidthInBasedNum-ML | JM_E1 |
| ParamWidthMismatch-ML | JM_E1 |
| SensListRepeat-ML | JM_E1 |
| SetBeforeRead-ML | JM_E1 |
| W154 | JM_E1 |
| W159 | JM_E1 |
| W493 | JM_E1 |

### JM_E2 (Mandatory Fix)

| Lint Rule | JMTAG |
|-----------|-------|
| ChkUndefMacro-ML | JM_E2 |
| STARC05-2.1.4.5 | JM_E2 |
| STARC05-3.3.3.1 | JM_E2 |
| UndrivenInTerm-ML | JM_E2 |
| AMSKeyword-ML | JM_E2 |
| badimplicitSM2 | JM_E2 |
| CheckPinConnectedToSupply | JM_E2 |
| DirectiveCheck-ML | JM_E2 |
| DisallowCaseX-ML | JM_E2 |
| DisallowCaseZ-ML | JM_E2 |
| FlopClockConstant | JM_E2 |
| FlopSRConst | JM_E2 |
| InstName | JM_E2 |
| PortName | JM_E2 |
| IntReset | JM_E2 |
| LatchGatedClock | JM_E2 |
| NoDefine | JM_E2 |
| NoGates | JM_E2 |
| NoGenLabel-ML | JM_E2 |
| NonConstReset-ML | JM_E2 |
| NoScripts | JM_E2 |
| NoVerilogPrims-ML | JM_E2 |
| OneModule-ML | JM_E2 |
| OnePortLine | JM_E2 |
| SignedUnsignedExpr-ML | JM_E2 |
| STARC05-1.1.1.1 | JM_E2 |
| STARC05-1.2.1.2 | JM_E2 |
| STARC05-1.3.1.3 | JM_E2 |
| STARC05-2.10.3.1 | JM_E2 |
| STARC05-2.10.6.1 | JM_E2 |
| STARC05-2.2.1.2 | JM_E2 |
| STARC05-2.2.3.1 | JM_E2 |
| STARC05-2.2.3.3 | JM_E2 |
| STARC05-2.3.1.5b | JM_E2 |
| STARC05-2.3.6.1 | JM_E2 |
| STARC05-2.6.1.3 | JM_E2 |
| STARC05-2.6.1.4a | JM_E2 |
| STARC05-2.7.2.2 | JM_E2 |
| STARC05-2.8.1.4 | JM_E2 |
| STARC05-2.8.4.3 | JM_E2 |
| STARC05-2.9.2.3 | JM_E2 |
| STARC05-3.3.2.2 | JM_E2 |
| TristatePort-ML | JM_E2 |
| UndrivenNUnloaded-ML | JM_E2 |
| UseMuxBusses | JM_E2 |
| W127 | JM_E2 |
| W156 | JM_E2 |
| W187 | JM_E2 |
| W193 | JM_E2 |
| W210 | JM_E2 |
| W263 | JM_E2 |
| W287a | JM_E2 |
| W293 | JM_E2 |
| W317 | JM_E2 |
| W323 | JM_E2 |
| W328 | JM_E2 |
| W362 | JM_E2 |
| W442a | JM_E2 |
| W442b | JM_E2 |
| W443 | JM_E2 |
| W444 | JM_E2 |
| W448 | JM_E2 |
| W453 | JM_E2 |
| W486 | JM_E2 |
| W71 | JM_E2 |
| W88 | JM_E2 |

### JM_E3 (Check & Conditional Fix/Waive)

| Lint Rule | JMTAG |
|-----------|-------|
| W163 | JM_E3 |
| W164a | JM_E3 |
| W164b | JM_E3 |
| W164c | JM_E3 |
| ActLowName | JM_E3 |
| ArrayIndex | JM_E3 |
| ClkName | JM_E3 |
| EnumStateDecl-ML | JM_E3 |
| HangingFlopOutput-ML | JM_E3 |
| NoInoutPort-ML | JM_E3 |
| ResetName | JM_E3 |
| STARC05-1.1.1.4 | JM_E3 |
| STARC05-1.4.1.1 | JM_E3 |
| STARC05-2.10.1.7 | JM_E3 |
| STARC05-2.10.1.8 | JM_E3 |
| STARC05-2.3.1.4 | JM_E3 |
| STARC05-2.3.6.2b | JM_E3 |
| STARC05-3.3.2.3 | JM_E3 |
| UnInitParam-ML | JM_E3 |
| UnloadedOutTerm-ML | JM_E3 |
| W120 | JM_E3 |
| W143 | JM_E3 |
| W146 | JM_E3 |
| W162 | JM_E3 |
| W17 | JM_E3 |
| W456a | JM_E3 |
| W488 | JM_E3 |
| W489 | JM_E3 |
| W491 | JM_E3 |
| W527 | JM_E3 |

### JM_Warning (Check & Conditional Fix/Waive)

| Lint Rule | JMTAG |
|-----------|-------|
| SelfAssignment-ML | JM_Warning |
| W502 | JM_Warning |
| W552 | JM_Warning |
| W553 | JM_Warning |
| CheckDelayTimescale-ML | JM_Warning |
| ConstantInput-ML | JM_Warning |
| ConstDrivenNet-ML | JM_Warning |
| DiffTimescaleUsed-ML | JM_Warning |
| ExprParen | JM_Warning |
| FuncName | JM_Warning |
| GenvarUsage-ML | JM_Warning |
| LineLength | JM_Warning |
| NameLength | JM_Warning |
| NoBusPartClock-ML | JM_Warning |
| OneStmtLine | JM_Warning |
| ParamOverrideMismatch-ML | JM_Warning |
| RptNegEdgeFF-ML | JM_Warning |
| STARC05-1.3.2.1b | JM_Warning |
| STARC05-2.10.6.6 | JM_Warning |
| STARC05-2.11.4.2 | JM_Warning |
| STARC05-2.3.5.1 | JM_Warning |
| STARC05-3.1.3.1 | JM_Warning |
| STARC05-3.1.3.4a | JM_Warning |
| STARC05-3.1.3.4b | JM_Warning |
| STARC05-3.5.6.4 | JM_Warning |
| UnloadedInPort-ML | JM_Warning |
| UnloadedNet-ML | JM_Warning |
| W111 | JM_Warning |
| W129 | JM_Warning |
| W175 | JM_Warning |
| W191 | JM_Warning |
| W215 | JM_Warning |
| W216 | JM_Warning |
| W218 | JM_Warning |
| W34 | JM_Warning |
| W350 | JM_Warning |
| W351 | JM_Warning |
| W464 | JM_Warning |
| W526 | JM_Warning |
| W563 | JM_Warning |
| W701 | JM_Warning |

### JM_Info (Check & Conditional Fix/Waive)

| Lint Rule | JMTAG |
|-----------|-------|
| ClockDomain | JM_Info |
| SVConstruct-ML | JM_Info |
| W433 | JM_Info |
| W446 | JM_Info |

### JM_HARDEN (User Confirmation Required)

| Lint Rule | JMTAG |
|-----------|-------|
| NoFeedThrus-ML | JM_HARDEN |
| RegOutputs | JM_HARDEN |
| STARC05-1.1.4.6a | JM_HARDEN |
| W240 | JM_HARDEN |

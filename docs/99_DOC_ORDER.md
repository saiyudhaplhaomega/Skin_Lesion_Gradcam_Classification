# Guide Order

This is the canonical reading order.

## Start

1. `00_RESUME_HERE.md`
2. `00_EXECUTION_PLAN.md`          -- Authoritative implementation plan and decisions
3. `00_START_HERE.md`
4. `01_BUILD_ORDER.md`
5. `02_ULTIMATE_PRODUCTION_GUIDE.md`
6. `03_DOMAIN_PRIMER.md`           -- Skin lesion domain context (HAM10000, classes, Fitzpatrick, clinical framing)
7. `03_ARCHITECTURE_OVERVIEW.md`   -- System diagram and role access boundaries
8. `04_GRADCAM_CLINICAL_INTERPRETATION.md` -- How to read heatmaps clinically
9. `05_BUILD_STATUS.md`            -- What is built vs planned (keep current)
10. `06_RESEARCH_BRIDGE.md`        -- How notebooks connect to production pipeline
11. `07_RAG_EVAL_AND_MULTI_AGENT_EXECUTION_PLAN.md` -- RAG eval and model eval planning (internal, not tracked in git)
12. `08_APPLICATION_FEATURES.md`
13. `99_DOC_ORDER.md`

## Design Specs

Read these before or during frontend design handoff:

- `responsive-grid-spec.md`
- `accessibility-interaction-spec.md`
- `microcopy-style-guide.md`

## Concepts Catalog

Read this once before the local-dev phase, then return to it whenever a guide says "Concepts you just touched":

- `reference/09_SYSTEM_DESIGN_PATTERNS.md`

## Local Development

12. `local-dev/01_LOCAL_BACKEND_FIRST.md`
13. `local-dev/02_LOCAL_FRONTEND_AFTER_BACKEND.md`
14. `local-dev/03_BACKEND_API_HANDHOLDING.md`
15. `local-dev/04_DATABASE_AND_MIGRATIONS_HANDHOLDING.md`
16. `local-dev/05_UPLOAD_AND_MOCK_PREDICTION_HANDHOLDING.md`
17. `local-dev/06_MODEL_AND_GRADCAM_HANDHOLDING.md`
18. `local-dev/07_FRONTEND_WORKFLOW_HANDHOLDING.md`
19. `local-dev/08_MAKEFILE_TESTING_HANDHOLDING.md`
20. `local-dev/09_DOCS_VALIDATION_HANDHOLDING.md`
21. `local-dev/10_FRONTEND_SEO_HANDHOLDING.md`
22. `local-dev/11_FULL_PROJECT_TEST_PLAN.md`
23. `local-dev/12_DOCKER_COMPOSE_HANDHOLDING.md`
24. `local-dev/13_CIRCUIT_BREAKER_HANDHOLDING.md`
25. `local-dev/14_CONFIDENCE_CALIBRATION_HANDHOLDING.md`
26. `local-dev/15_AMP_TRAINING_OPTIMIZATION.md`
27. `local-dev/16_FRONTEND_API_WIRING_HANDHOLDING.md`

## Product Features

27. `product/01_BACKEND_DOMAIN_ARCHITECTURE_HANDHOLDING.md`
28. `product/02_DOMAIN_MODEL_AND_API_CONTRACTS_HANDHOLDING.md`
29. `product/03_PROFESSIONAL_FEATURE_SEQUENCE.md`
30. `product/04_PRIVACY_CONSENT_STORAGE_HANDHOLDING.md`
31. `product/05_LESION_BODY_MAPPING_HANDHOLDING.md`
32. `product/06_SAFE_LLM_EXPLANATION_HANDHOLDING.md`
33. `product/07_LANGCHAIN_ADK_OBSERVABILITY_HANDHOLDING.md`
34. `product/08_CUSTOMER_DASHBOARD_HANDHOLDING.md`
35. `product/09_SEO_AND_PUBLIC_PAGES_HANDHOLDING.md`
36. `product/10_DOCTOR_ADMIN_REPORTS_HANDHOLDING.md`
37. `product/11_LAB_RESULTS_HANDHOLDING.md`
38. `product/12_RESEARCH_FAIRNESS_MONITORING_HANDHOLDING.md`
39. `product/13_LLM_RAG_AGENT_BOUNDARIES_HANDHOLDING.md`
40. `product/14_ROLE_BASED_EVOLVING_AGENTS_HANDHOLDING.md`
41. `product/15_ADMIN_MARKET_RESEARCH_RAG_HANDHOLDING.md`
42. `product/16_MOBILE_APP_HANDHOLDING.md`
43. `product/17_TRAINING_PIPELINE_MODEL_REGISTRY_HANDHOLDING.md`
44. `product/18_LAB_OCR_EXTRACTION_HANDHOLDING.md`

## Staging Transition

45. `staging/00_CLOUD_COST_CONTROL_HANDHOLDING.md`
46. `staging/01_DOCKER_HANDHOLDING.md`
47. `staging/02_TERRAFORM_FROM_EMPTY_MAIN.md`
48. `staging/03_TERRAFORM_VPC_HANDHOLDING.md`
49. `staging/04_TERRAFORM_PARAMETERS_AND_BOOTSTRAP_HANDHOLDING.md`
50. `staging/05_TERRAFORM_STORAGE_SECRETS_AND_ECR_HANDHOLDING.md`
51. `staging/06_KUBERNETES_AFTER_DOCKER.md`
52. `staging/07_KUBERNETES_LOCAL_HANDHOLDING.md`
53. `staging/08_ECR_AND_EKS_HANDHOLDING.md`
54. `staging/09_EKS_INGRESS_ALB_CONTROLLER_HANDHOLDING.md`
55. `staging/10_TERRAFORM_DATABASE_AND_EVENTS_HANDHOLDING.md`
56. `staging/11_AURORA_DSQL_STAGING_HANDHOLDING.md`
57. `staging/12_EVENT_WORKFLOW_AFTER_LOCAL_API.md`
58. `staging/13_EVENTS_SQS_WORKER_HANDHOLDING.md`
59. `staging/14_SECURITY_COMPLIANCE_HANDHOLDING.md`
60. `staging/15_OBSERVABILITY_RELIABILITY_HANDHOLDING.md`
61. `staging/16_TERRAFORM_SECURITY_OBSERVABILITY_HANDHOLDING.md`
62. `staging/17_CICD_HANDHOLDING.md`
63. `staging/18_LOCAL_TO_STAGING_TO_PRODUCTION_HANDHOLDING.md`
64. `staging/19_POWERBI_EMBEDDED_ANALYTICS_HANDHOLDING.md`
65. `staging/20_ELASTICACHE_REDIS_HANDHOLDING.md`
66. `staging/21_MLFLOW_SERVER_HANDHOLDING.md`
67. `staging/22_VERCEL_FRONTEND_STAGING_HANDHOLDING.md`
68. `staging/23_FRONTEND_ROUTE_WIRING_AUDIT.md`

## Production Readiness

69. `production/01_CLOUD_INFRASTRUCTURE_PATH.md`
70. `production/02_KUBERNETES_EKS_PATH.md`
71. `production/03_EVENT_WORKFLOW_PATH.md`
72. `production/04_DATABASE_MULTI_REGION_PATH.md`
73. `production/05_OPERATIONS_RELIABILITY_COST.md`
74. `production/06_MODEL_FAIRNESS_MONITORING_PATH.md`
75. `production/07_RUNTIME_ALTERNATIVES_EKS_AND_ECS.md`
76. `production/08_RELEASE_STRATEGIES_BLUE_GREEN_CANARY.md`
77. `production/09_AUTO_HEAL_AND_ROLLBACK_LAMBDA_PATH.md`
78. `production/10_EKS_AUTO_HEAL_AND_ROLLBACK_HANDHOLDING.md`
79. `production/11_APPCONFIG_FEATURE_FLAGS_HANDHOLDING.md`
80. `production/12_CACHE_REDIS_ELASTICACHE_HANDHOLDING.md`

## Reference

81. `reference/01_FULL_PROJECT_ROADMAP.md`
82. `reference/02_REQUIREMENTS_SECURITY_COMPLIANCE.md`
83. `reference/03_FUTURE_PLANS_REBUILT.md`
84. `reference/04_RECOVERY_AND_SOURCE_NOTES.md`
85. `reference/05_3D_BODY_MAPPING_PATH.md`
86. `reference/06_AGENTIC_XAI_ADK_PATH.md`
87. `reference/07_MOBILE_REACT_NATIVE_PATH.md`
88. `reference/08_INFRA_MODULE_COVERAGE_AUDIT.md`
89. `reference/09_SYSTEM_DESIGN_PATTERNS.md`

## How To Use This

The local development path proves the app on your machine.

The product path adds the healthcare/XAI workflows, separated role-based RAG agents, admin market research intelligence, and public SEO pages. SEO applies only to public education and marketing routes, not private app routes.

The staging path teaches deployment, promotion, analytics integration, and operational checks before production.

The production path explains the production-style architecture and operating model.

The reference path preserves advanced plans and background decisions.

## Anti-Guessing Rule

Before you paste code, check the guide for:

1. the directory to run from
2. the exact file path to create or edit
3. the check command to run after the change

If any guide is missing one of those three things, stop and fix the guide before building the code.

## Cost Pause / Resume

If this guide created or uses cloud resources, pause or shut them down before stopping for the day.

Run from the repo root:

```powershell
make cloud-status ENV=dev
make cloud-pause ENV=dev
make cloud-shutdown ENV=dev CONFIRM_DESTROY=YES
```

What this command block does:

- `make cloud-status ENV=dev` checks the dev cloud environment state.
- `make cloud-pause ENV=dev` pauses resources that can be stopped temporarily.
- `make cloud-shutdown ENV=dev CONFIRM_DESTROY=YES` intentionally destroys dev resources after explicit confirmation.

Use `ENV=staging` or `ENV=prod` only when you are intentionally working in that environment.

Before starting the next guide, resume the environment and re-run the guide's check command:

```powershell
make cloud-start ENV=dev
make cloud-status ENV=dev
```

What this command block does:

- `make cloud-start ENV=dev` starts or resumes the dev environment.
- `make cloud-status ENV=dev` verifies the environment state after startup.

If this guide was local-only, no cloud shutdown is needed.

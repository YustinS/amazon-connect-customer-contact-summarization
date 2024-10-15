# Amazon Connect Custom Contact Summarization

A custom solution to process Amazon Connect Contact Lens Transcripts into Summaries that can be varied based on desired prompts. This is intended for Contact Centres that do not/cannot access the default Summarization in Contact Lens (only available in US at time of writing) or needs the ability to adjust and refine prompts into a custom output.

## About

This is a solution to allow extracting transcripts from Contact Lens, optionally redact the content (since pulling the realtime transcript with redactions is not available for VOICE calls at this time), and then submit to Bedrock to generate a summary.

By default the transcript (redacted if enabled) and the summary are also stored in S3 with short term retention for validation purposes.

This solution also includes a version that will automatically submit all valid VOICE calls to be processed as well, so all calls can be automatically processed as needed.

## Prerequisites

- [Add the relevant model access to Amazon Bedrock](https://docs.aws.amazon.com/bedrock/latest/userguide/model-access-modify.html)
- Enable realtime contact lens within your contact flows

## Deployment

This codebase follows a consistent pattern to deploy, you just need to build the code, then move the appropriate environment files (`version.tf` and `terraform.tfvars`) into the directory alongside the other TF files

1. navigate to [code/call-summarization/](./code/call-summarization/)
2. Run `nvm use` (assuming you have NVM installed) to initialize the NodeJS version the code is built with
3. Adjust the prompt and system prompt as needed in [helpers.ts](./code/call-summarization/src/helpers.ts), lines 236-253 in the base repo.
4. Run `npm run package` to lint and build the codebase. This will generate the ZIP file OpenTofu/Terraform needs
5. Navigate to [infra/](./infra/)
6. Copy the relevant environment files from their folder into the same directory as the rest of the files
7. Make adjustments as required. For example, you may remove the/disable the Eventbridge rule that automatically summarizes if only the API functionality is needed.
8. Deploy as required. `terraform init`/`tofu init`, `terraform plan -out plan.tfplan`/`tofu plan -out plan.tfplan`, and `terraform apply plan.tfplan`/`tofu apply plan.tfplan` as you normally would
9. Review and test

## Enhancements

- Use OAuth2 to control access to the API. This is general best practice, and means its easier to review who has been requesting

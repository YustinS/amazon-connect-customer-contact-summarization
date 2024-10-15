import { APIGatewayProxyEvent, APIGatewayProxyResult } from 'aws-lambda';
import { 
  RetrieveTranscriptSegments,
  ConstructTranscriptContent, 
  RedactPiiContent, 
  GenerateConversationSummary,
  StoreS3Content
} from "./helpers"

const S3BUCKET = process.env.S3_BUCKET!;
const INSTANCEARN = process.env.INSTANCE_ARN;
const PIICONFIDENCE = parseFloat(process.env.PIICONFIDENCE || "0.75")
const CORSDOMAIN = process.env.CORS_DOMAIN || "*";
const REDACTION = (process.env.REDACTION_ENABLED || "true").toLowerCase() === "true";
const BEDROCKMODEL = process.env.BEDROCK_MODEL || "anthropic.claude-3-haiku-20240307-v1:0";
const RUNSUMMARY = (process.env.RUN_SUMMARY || "false").toLowerCase() === "true";

type SummaryResponseBody = {
  // Technically either of these could be disabled or
  // never be added
  transcript?: string | undefined,
  summary?: string | undefined
}

  
export const lambda_handler = async (
    event: APIGatewayProxyEvent,
): Promise<APIGatewayProxyResult> => {

  const responseContent: APIGatewayProxyResult = {
      "statusCode": 500,
      "headers": {
          "Content-Type": "application/json",
          "Access-Control-Allow-Origin": CORSDOMAIN,
          "Access-Control-Allow-Headers": "Content-Type",
          "Access-Control-Allow-Methods": "*",
          "X-XSS-Protection": "1; mode=block",
          "X-Content-Type-Options": "nosniff",
          "Content-Security-Policy": "default-src 'self'",
          "Strict-Transport-Security": "max-age=63072000",
          "X-Frame-Options": "DENY",
      },
      "body": ""
  }


  const responseBody: SummaryResponseBody = {}
  
  console.info(JSON.stringify(event))

  try {

    const requestBody = JSON.parse(event.body!)

    const contactId = requestBody.contactId
    const instanceArn = requestBody?.instanceArn ?? INSTANCEARN
    const instanceId = instanceArn.substring(instanceArn.lastIndexOf("/") + 1);
    
    const segments =  await RetrieveTranscriptSegments(
      contactId,
      instanceId
    )
    
    const speakerFormattedContent = await ConstructTranscriptContent(segments);

    let transcript: string;
    
    if (REDACTION && speakerFormattedContent.length > 10){
      console.debug("Entering Redaction Enabled Block")
      transcript = await RedactPiiContent(speakerFormattedContent, PIICONFIDENCE);
    } else {
      transcript = speakerFormattedContent;
    }

    responseBody.transcript = transcript

    const dateObj = new Date();
    const month   = String(dateObj.getUTCMonth() + 1); // months from 1-12
    const day     = String(dateObj.getUTCDate());
    const year    = String(dateObj.getUTCFullYear());

    const dateTimeKey = `${year}/${month.padStart(2, '0')}/${day.padStart(2, '0')}/${contactId}.txt`;
    const fileKey = `transcripts/${dateTimeKey}`

    console.info(`Generated file key ${fileKey}`)

    await StoreS3Content(S3BUCKET, fileKey, transcript)

    if (RUNSUMMARY){
      console.debug("Entering Summary Block")
      
      // Speaker labels add a lot of tokens to the transcript.
      // Lets reduce these to save some tokens
      let reducedTranscript = transcript;
      const agentReplace = new RegExp("AGENT:", "g");
      const customerReplace = new RegExp("CUSTOMER:", "g");
      reducedTranscript = reducedTranscript.replace(agentReplace,`A:`);
      reducedTranscript = reducedTranscript.replace(customerReplace,`C:`);
      
      const summary = await GenerateConversationSummary(reducedTranscript, BEDROCKMODEL);
      responseContent.statusCode = 200
      responseBody.summary = summary
      
      const summaryKey = `summaries/${dateTimeKey}`;

      await StoreS3Content(S3BUCKET, summaryKey, summary)
      
    } else {
      console.debug("Not running summarization")
      responseContent.statusCode = 200
    }
  
  } catch (err) {
    console.error(err);
  }
  
  // Load the body
  responseContent.body = JSON.stringify(responseBody);
  console.info(`Finishing with response: ${JSON.stringify(responseContent)}`)

  return responseContent
};

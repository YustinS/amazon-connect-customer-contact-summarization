import { 
    ComprehendClient, 
    DetectPiiEntitiesCommand,
    DetectPiiEntitiesRequest 
} from "@aws-sdk/client-comprehend";
import { 
    ConnectContactLensClient, 
    ListRealtimeContactAnalysisSegmentsCommand, 
    RealtimeContactAnalysisSegment,
    ListRealtimeContactAnalysisSegmentsRequest
} from "@aws-sdk/client-connect-contact-lens";
import {
    BedrockRuntimeClient,
    ConverseCommand,
} from "@aws-sdk/client-bedrock-runtime";
import { PutObjectCommand, S3Client } from "@aws-sdk/client-s3";

const AWSREGION = process.env.AWS_REGION || 'ap-southeast-2';
const CONTACTLENSCLIENT = new ConnectContactLensClient({ region: AWSREGION });
const COMPREHENDCLIENT = new ComprehendClient({ region: AWSREGION });
const BEDROCKCLIENT = new BedrockRuntimeClient({ region: AWSREGION });
const S3CLIENT = new S3Client()

const REDACTEDTYPES = [
    "BANK_ACCOUNT_NUMBER",
    "BANK_ROUTING",
    "CREDIT_DEBIT_NUMBER",
    "CREDIT_DEBIT_CVV",
    "CREDIT_DEBIT_EXPIRY",
    "PIN",
    "EMAIL",
    "ADDRESS",
    "NAME",
    "PHONE", 
    "DATE_TIME",
    "PASSPORT_NUMBER",
    "DRIVER_ID", 
    "URL",
    "AGE",
    "USERNAME",
    "PASSWORD"
]

/**
  * Retrieve the Transcripts for the given Contact ID. This will filter out
  * to only transcript data as the Segment Data
  * @param {string} contactId UUID of the Contact ID to lookup. Note that after 24 hours
  *     this will not be accessible via API
  * @param {string} instanceId UUID of the Connect Instance the Contact was related to
  * @return {Promise<RealtimeContactAnalysisSegment[]>} Promise of RealtimeContactAnalysisSegment,
  *     filtered to only the Transcript typed data 
*/
export const RetrieveTranscriptSegments = async (
    contactId: string,
    instanceId: string,
  ): Promise<RealtimeContactAnalysisSegment[]> =>{
    // Retrieve the transcript segments and filter to
    // only the transcript types
    console.info("Retrieving transcripts")

    const returnResults = []
    let processing = true
    let nextToken = null;
    
    while(processing){
      const input: ListRealtimeContactAnalysisSegmentsRequest = { // ListRealtimeContactAnalysisSegmentsRequest
        InstanceId: instanceId, // required
        ContactId: contactId, // required
        MaxResults: 100,
      };
      
      if (nextToken !== null) {
        input.NextToken = nextToken
      }
      
      const command = new ListRealtimeContactAnalysisSegmentsCommand(input);
      const {Segments, NextToken} = await CONTACTLENSCLIENT.send(command);

      if (!Segments) {
        processing = false;
        break;
      }
      
      const reduce = Segments.filter( i => Object.keys(i).includes("Transcript"));
      returnResults.push(...reduce)
      
      if (NextToken) {
        nextToken = NextToken;
      } else {
        processing = false
      }
    }
    return returnResults
  }

/**
  * Retrieve the Transcripts for the given Contact ID. This will filter out
  * to only transcript data as the Segment Data
  * @param {RealtimeContactAnalysisSegment[]} transcriptSegments Segments of Transcript as retrieved
  *   from Amazon Connect. Expected to be jus tthe Transcript types
  * @return {Promise<string>} Constructed string of the Transcript, showing turns of the conversation.
*/
export const ConstructTranscriptContent = async (
    transcriptSegments: RealtimeContactAnalysisSegment[],
  ): Promise<string> =>{
    console.info("Processing into transcript")

    const lines = []
    let line = "";
    let speaker = "UNKNOWN";
    let mostRecentSpeaker = "UNKNOWN";
    
    for(const entry of transcriptSegments) {
      // Filtered to only Transcript values on retrieval,
      // this cannot be null, so enforce the type check
      const values = entry.Transcript!;

      // Gets the speaker as a single character to reduce excess token usage in
      // summarization. Unknown should exist but is kept as a guard case
      const participant = values.ParticipantId
      if (!participant) {
        speaker = "UNKNOWN" // for unknown
      } else {
        speaker = participant
      }
      
      if(speaker == mostRecentSpeaker){
        // Same speaker, so append as a single line
        line += ` ${values.Content}`
      } else {
        if (line.length > 0){
          // Speaker has changed and content exists
          lines.push(`${line} \n`)
        }
        mostRecentSpeaker = speaker;
        //line = ` ${values.BeginOffsetMillis} ${speaker} ${values.Content}`
        line = `${speaker}: ${values.Content}`
      }
    }
    // Append the final line of content
    lines.push(line)
    
    // Switch to string so it prints cleanly/
    // can be written to file
    return lines.join("")
  }

/**
  * Retrieve the Transcripts for the given Contact ID. This will filter out
  * to only transcript data as the Segment Data
  * @param {string} message The Transcript of the discussion as converted into string types
  * @param {number} confidenceScore Minimum score required for data to be redacted, so that
  *     low confidence data is not removed
  * @return {Promise<string>} Transcript, with data redacted as identified
*/
export const RedactPiiContent = async (
  message: string,
  confidenceScore: number
): Promise<string> =>{
  // Take a string message, identify the PII strings, 
  // and then redact out PII data
  console.info("Checking for redactable PII content")
  
  // Create a new copy of the string rather than the original
  let returnString: string = message

  console.debug(`Input message of length ${message.length}`)

  if (message.length == 0){
    return message
  }

  const input: DetectPiiEntitiesRequest = { // DetectPiiEntitiesRequest
    Text: message, // required
    LanguageCode: "en"
  };
  const command = new DetectPiiEntitiesCommand(input);
  const { Entities } = await COMPREHENDCLIENT.send(command);

  if (!Entities) {
    console.info("No PII Entities detected!")

  } else {
    // Retrieve all the replacements
    for (const entity of Entities){
      if (
        REDACTEDTYPES.includes(entity.Type!) && 
        entity.Score! > confidenceScore
      ){
        const start = entity.BeginOffset!
        const end = entity.EndOffset!
        const redactString = message.substring(start, end)
        // Generate the replacements. Note that NodeJS does a SINGLE
        // replace per call, so it should do 1-to-1 replacement mappings 
        // due to response being in FIFO order

        // To do general ALL replacements instead the following can be done
        // const replacement = new RegExp(redactString, "g")
        // returnString = returnString.replace(replacement,`[${entity.Type}]`)
        console.debug(`Redacting "${redactString}" with "[${entity.Type}]"`)
        returnString = returnString.replace(redactString,`[${entity.Type}]`) 
      }
    }
  }

  console.debug(`Response message of length ${returnString.length}`)

  return returnString
}

/**
  * Retrieve the Transcripts for the given Contact ID. This will filter out
  * to only transcript data as the Segment Data
  * @param {string} transcript The Transcript of the discussion as converted into string types.
  *     This can be Redacted or Unredacted depending on configuration
  * @param {string} modelId The Bedrock Model ID that will be invoked.
  *     NOTE: This needs to be enabled in the AWS Console to be used by requesting access
  * @return {Promise<string>} The summary as generated from the input transcript using 
  *     the provided model
*/
export const GenerateConversationSummary = async(
  transcript: string,
  modelId: string,
): Promise<string> =>{
  
  console.info("Attempting to generate summary via AWS Bedrock")
  if (transcript.length < 10) {
    return "Not enough discussion to summarize"
  }

  /* eslint-disable max-len */ 
  const instructions = `
  The following is a transcript from a call to a contact center, between an Agent (indicated by lines starting with 'A:') and a Customer (lines starting with 'C:').
  Redacted Personally Identifiable Information (PII) is identified by its type between square brackets.
  For example, '[NAME]' indicates a name was redacted from the conversation, and no further attempts should be made to glean what was redacted.
  Information in square brackets such as [NAME] are NOT to be included in your responses
  The transcript is as follows contained within <text></text> XML tags:

  <text>
  ${transcript}
  </text>

  Your task is to take the transcript and, as if from the Agents perspective and in past tense, written in the passive as actions that happened, without including any PII as indicated by squared brackets:
    - generate a concise summary of the overall conversation under the title "Summary", aiming for around 200 words maximum. The context of the conversation does not need to be included.
    - highlight the key discussed items in bullet points under the title "Key Items"
    - list any action items that are outstanding from either the Agent or Customer and who needs to do them under the title "Actions"
  `;

  const systemPrompt = `You are a Contact Centre Agent completing post call tasks like writing notes after the call. Do not invent discussions, strictly use the provided inputs to generate the request.`
  /* eslint-enable max-len */

  // Create a command with the model ID, the message, and a basic configuration.
  const command = new ConverseCommand({
    modelId: modelId,
    messages: [
      {
        role: "user",
        content: [{ text: instructions }],
      },
    ],
    inferenceConfig: { 
      maxTokens: 4096, 
      temperature: 0, 
      topP: 0.9 
    },
    system: [
      {
        text: systemPrompt
      }
    ]
  });

  try {
    // Send the command to the model and wait for the response
    const response = await BEDROCKCLIENT.send(command);
    console.debug(`Bedrock Response: ${JSON.stringify(response)}`)

    // Extract and print the response text. Enforce that the type will be included
    // with !
    const responseMessage = response.output!.message!
    const responseText = responseMessage.content![0].text!;
    console.info(responseText);
    return responseText
  } catch (err) {
    console.error(`Can't invoke '${modelId}'. Reason: ${err}`);
    return "Error running summarization. Please resolve manually."
  }
}

/**
  * Retrieve the Transcripts for the given Contact ID. This will filter out
  * to only transcript data as the Segment Data
  * @param {string} bucketName The name of the S3 Bucket to upload the content to
  * @param {string} bucketKey The file key the content will be uploaded to
  * @param {string} content The content of the file to be uploaded to the S3 Bucket
  * @return {Promise<boolean>} Boolean indicating the outcome of the S3 Bucket write
*/
export const StoreS3Content = async(
  bucketName: string,
  bucketKey: string,
  content: string,

): Promise<boolean> => {
  
  console.info(`Attempting to write to ${bucketName}, file key ${bucketKey}`)
  
  const s3Command = new PutObjectCommand({
    Bucket: bucketName,
    Key: bucketKey,
    Body: content,
  });

  try {
    const s3Response = await S3CLIENT.send(s3Command);
    console.debug(`S3 response: ${JSON.stringify(s3Response)}`)
    return true
  } catch (err) {
    console.error(err);
    return false
  }
}
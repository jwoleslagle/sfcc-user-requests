const AWS = require('aws-sdk');
AWS.config.update({region: 'us-east-1'}); //process.env.SES_REGION//must run before ses and s3 instantiate
const s3 = new AWS.S3({signatureVersion: 'v4'});
const ses = new AWS.SES();
const bucket = process.env.S3_UPLOAD_BUCKET;
const srcEmail = process.env.SRC_EMAIL;
const destEmail = process.env.DEST_EMAIL;

async function getUploadUrl(parameters) {
    const data = await new Promise((resolve, reject) => {
        try {
            s3.getSignedUrl('getObject', parameters, (err, url) => {
                console.log("Signed URL created.")
                resolve(url)
            })
        }
        catch (error) {
            reject(error);
        }
    });
    return data;
}

async function createEmail(signedUrl) {
    const email = {
        Destination: {
            ToAddresses: [destEmail]
        },
        Message: 
        {
        Body: {
            Text: { Data: `Please find the requested signed url below:\n\n${signedUrl}\n\nUse this url on the page where you requested this URL.\n\nPlease note:\n1) This signed url will expire in 30 min, and is one-time use only.\n 2) Make sure the upload filename matches what was provided.`
            }
            },
            Subject: { Data: "Signed URL for SFCC bulk access requests"  
            }
        },
        Source: srcEmail
    };
    return email;
}

async function sendEmail(params) {
    const sendPromise = await ses.sendEmail(params).promise();
    return sendPromise;
}

module.exports.handler=async(event) =>{
    const data = JSON.parse(event.body);
    const key = data.fname;
    const params = {'Bucket': bucket, 'Key': key, Expires: 1800};
    const urlPromise = getUploadUrl(params);
    //create the email
    const emailParams = createEmail(await urlPromise);
    //send the email
    const emailResp = sendEmail(await emailParams);
    console.log(`Email sent: ${await emailResp}`);
    return {
        "statusCode": 200, 
        "body": JSON.stringify(await emailResp)}
}
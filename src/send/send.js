const AWS = require('aws-sdk');
AWS.config.update({region: process.env.SES_REGION}); //must run before ses and s3 instantiate
const s3 = new AWS.S3({signatureVersion: 'v4'});
const ses = new AWS.SES();
const bucket = process.env.S3_UPLOAD_BUCKET;
const srcEmail = process.env.SRC_EMAIL;
const destEmail = process.env.DEST_EMAIL;
//Required to parse x-www-form-urlencoded
const querystring = require('querystring');

async function getUploadUrl(parameters) {
    const data = await new Promise((resolve, reject) => {
        try {
            s3.getSignedUrl('putObject', parameters, (err, url) => {
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
            Text: { Data: `Please find the requested signed url below:\n\n<!----Copy / paste everything between these lines---->\n${signedUrl}\n!----Copy / paste everything between these lines---->\n\nUse this url on the page where you requested this URL.\n\nPlease note:\n1) This signed url will expire in 15 min, and is one-time use only.\n 2) Make sure the upload filename matches what was provided.`
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
    let data = {};
    try {
        data = JSON.parse(event.body);
    } catch (error) {
        console.log("Object is not JSON, trying to parse x-www-form-urlencoded.");
        data = querystring.parse(event.body);
    }
    //Leading fwd slash may be required to pass signature check
    const key = `uploads/${data.fname}`;
    console.log(`Key is: ${key}`)
    const params = {
        'Bucket': bucket, 
        'Key': key};
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
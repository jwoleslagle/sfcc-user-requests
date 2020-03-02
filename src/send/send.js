'use strict';

const AWS = require('aws-sdk');
const s3 = new AWS.S3({signatureVersion: 'v4'});
const ses = new AWS.SES({region: 'us-east-1'});
const bucket = process.env.S3_UPLOAD_BUCKET;
const joi = require('joi');

exports.handler = (event, context, callback) => {
    const data = JSON.parse(evt.body);
    const schema = joi.object().keys({
        fname: joi.string().required(),
    });
  
    try{
        const {error, value} = joi.validate(data,schema);
    }
    catch(err) {
        return {
            status: 400,
            body: JSON.stringify(err.details)
        }
    }

    if (!bucket) {
        callback(new Error(`S3 bucket not set`));
    }
    
    const key = event.fname;
    if (!key) {
        callback(new Error('S3 object key missing'));
        return;
    }

    const params = {'Bucket': bucket, 'Key': key, Expires: 1800};
    
    s3.getSignedUrl('putObject', params, function (err, url) {
        if (err) {
        callback(err);
        } else {
            console.log('Signed URL was created.');
            const paramsSES = {
            Destination: {
                ToAddresses: [process.env.destEmail]
            },
            Message: {
            Body: {
                Text: { Data: `Please find the requested signed url below:\n\n${url}\n\nUse this url on the page where you requested this URL.\n\nPlease note:\n1) This signed url will expire in 30 min, and is one-time use only.\n 2) Make sure the upload filename matches what was provided.`
                }
                },
                Subject: { Data: "Signed URL for SFCC bulk access requests"  
                }
            },
            Source: process.env.srcEmail
            };
    
        ses.sendEmail(paramsSES, function (err, data) {
            callback(null, {err: err, data: data});
            if (err) {
                console.log(err);
                context.fail(err);
            } else {
                console.log(data);
                context.succeed(event);
            }
        });
    }
  });
};
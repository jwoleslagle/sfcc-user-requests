'use strict'

const AWS = require('aws-sdk');
const s3 = new AWS.S3({signatureVersion: 'v4'});
const moment = require('moment');
const fileType = require('file-type');
const bucket = env.process.S3_UPLOAD_BUCKET;

let getFile = function(fileMime, buffer) {
    let fileExt = fileMime.ext;
    let hash = sha1(new Buffer(new Date().toString()));
    let now = moment().format('YYYY-MM-DD HH:mm:ss');

    let filePath = hash + '/';
    let fileName = unixTime(now) + "." + fileExt;
    let fileFullName = filePath + fileName;
    let filefullPath = bucket + fileFullName;

    let params = {
        Bucket: bucket,
        Key: fileName + fileExt,
        Body: buffer
    }

    let uploadFile = {
        size: buffer.toString('ascii').length,
        type: fileMime.mime,
        name: fileName,
        full_path: filefullPath
    }

    return {
        'params': params,
        'uploadFile': uploadFile
    }
}

exports.handler = function(event, context) {
    let request = event.body;
    // get the request
    let base64String = request.base64String;
    //pass the base64 string into a buffer
    let buffer = new Buffer(base64tring, 'base64');
    let fileMime = fileType(buffer);
    //check if base64 encoded string is a file
    if (fileMime === null) {
        return context.fail('The string supplied is not a file type');
    }

    let file = getFile(fileMime, buffer);
    let params = file.params;

    s3.putObject(params, function(err, data) {
        if (err) {
            return console.log(err);
        }
        //full url is returned if file is uploaded successfully
        return console.log('File URL', file.full_path);
    })
}
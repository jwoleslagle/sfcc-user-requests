const AWS = require('aws-sdk');

console.log(`IS OFFLINE: ${process.env.IS_OFFLINE}`);
let options = {};
if (process.env.IS_OFFLINE) {
    options.region = 'localhost';
    options.endpoint = 'http://localhost:8000';
}
const dynamoDB = new AWS.DynamoDB.DocumentClient(options);

module.exports = dynamoDB;
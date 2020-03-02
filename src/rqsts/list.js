const dynamoDB = require('../dynamodb');

module.exports.handler=async(evt, ctx) =>{
    try{
        const results = await dynamoDB.scan({
            TableName: process.env.REQUESTS_TABLE
        }).promise();
        return {
            statusCode: 200,
            body: JSON.stringify({results})
        }
    }
    catch(error){
        return {
            statusCode: 500,
            body: JSON.stringify({error})
        }
    }
}
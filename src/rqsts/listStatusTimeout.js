const dynamoDB = require('../dynamodb');

module.exports.handler=async(evt, ctx) =>{
    try{
        const results = await dynamoDB.query({
            TableName: process.env.REQUESTS_TABLE,
            IndexName: "rqstStatus",
            KeyConditionExpression: "rqstStatus = :v_rqstStatus",
            ExpressionAttributeValues: {
                ":v_rqstStatus": "TIMEOUT"
            }
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
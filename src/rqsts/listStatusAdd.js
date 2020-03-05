const dynamoDB = require('../dynamodb');

module.exports.handler=async(evt, ctx) =>{
    try{
        const results = await dynamoDB.query({
            TableName: process.env.REQUESTS_TABLE,
            IndexName: "status",
            KeyConditionExpression: "rqstStatus = :v_rqstStatus",
            ExpressionAttributeValues: {
                ":v_rqstStatus": {"S": "ADD_ALL"}
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
const dynamoDB = require('../dynamodb');

module.exports.handler=async(evt, ctx) =>{
    const date = new Date();
    date.setDate(date.getDate()-7);
    const SevenDaysAgo = date.toISOString();
    
    try{
        const results = await dynamoDB.query({
            TableName: process.env.REQUESTS_TABLE,
            IndexName: "rqstStatus",
            KeyConditionExpression: "rqstStatus NOT IN (:v_error, :v_completed)",
            ConditionExpression: "createdAt <= :v_from",
            ExpressionAttributeValues: {
                ":v_from": SevenDaysAgo,
                ":v_completed": "COMPLETED",
                ":v_error": "ERROR"
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
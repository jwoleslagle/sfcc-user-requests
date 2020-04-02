const dynamoDB = require('../dynamodb');

module.exports.handler=async(evt, ctx) =>{
    const date = new Date();
    date.setDate(date.getDate()-7);
    const SevenDaysAgo = date.toISOString();
    
    try{
        const results = await dynamoDB.query({
            TableName: process.env.REQUESTS_TABLE,
            IndexName: "rqstStatus",
            KeyConditionExpression: "rqstStatus IN (:v_addInst)",
            ConditionExpression: "updatedAt <= :v_from",
            ExpressionAttributeValues: {
                ":v_from": SevenDaysAgo,
                ":v_addInst": "ADD_INST"
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
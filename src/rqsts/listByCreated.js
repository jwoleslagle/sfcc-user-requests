const joi = require('joi');
const dynamoDB = require('../dynamodb');

module.exports.handler=async(evt) =>{
    const data = JSON.parse(evt.pathParameters);

    const schema = joi.object().keys({
        daysAgo: joi.number().min(1).max(365).required(),
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

    const date = new Date();
    date.setDate(date.getDate() - data.daysAgo);
    const ISOdaysAgo = date.toISOString();
    
    try{
        const results = await dynamoDB.query({
            TableName: process.env.REQUESTS_TABLE,
            IndexName: "rqstStatus",
            KeyConditionExpression: "rqstStatus NOT IN (:v_error, :v_completed, :v_timeout)",
            ConditionExpression: "createdAt <= :v_from",
            ExpressionAttributeValues: {
                ":v_from": ISOdaysAgo,
                ":v_completed": "COMPLETED",
                ":v_error": "ERROR",
                ":v_timeout": "TIMEOUT"
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
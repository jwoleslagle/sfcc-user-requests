const dynamoDB = require('../dynamodb');

module.exports.handler=async(evt, ctx) =>{
    const id = evt.pathParameters.id;
    try {
        const results = await dynamoDB.delete({
            TableName : process.env.JOBS_TABLE,
            Key: {
                id: id
            }
        }).promise();
        return {
            statusCode: 200,
            body: JSON.stringify({msg: `Job has been deleted with id: ${id}.`})
        }
    } catch (error) {
        return {
            statusCode: 500,
            body: JSON.stringify(error)
        }
    }

}
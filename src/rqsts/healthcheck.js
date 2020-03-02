module.exports.handler=async (evt, ctx) => {
    return {
        statusCode: 200,
        body: JSON.stringify({
            message: "Pong",
            eventOutput: evt,
            contextOutput: ctx
        })
    }
}
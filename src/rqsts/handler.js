module.exports.handler=async (evt, ctx) => {
    console.log(evt);
    console.log(ctx);
    return {
        statusCode: 200,
        body: JSON.stringify({
            message: "Pong."
        })
    }
}
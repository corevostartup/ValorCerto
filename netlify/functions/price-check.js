const axios = require("axios");

function classifyPrice(userPrice, averagePrice) {
  if (userPrice > averagePrice * 1.1) return "caro";
  if (userPrice < averagePrice * 0.9) return "barato";
  return "ok";
}

function calculateDifferencePercent(userPrice, averagePrice) {
  return Math.round(((userPrice - averagePrice) / averagePrice) * 100);
}

exports.handler = async function handler(event) {
  if (event.httpMethod !== "POST") {
    return {
      statusCode: 405,
      body: JSON.stringify({ error: "Use POST" })
    };
  }

  try {
    const payload = JSON.parse(event.body || "{}");
    const barcode = payload.barcode;
    const userPrice = Number(payload.user_price);

    if (!barcode || Number.isNaN(userPrice) || userPrice <= 0) {
      return {
        statusCode: 400,
        body: JSON.stringify({
          error: "Payload inválido. Esperado: { barcode, user_price }"
        })
      };
    }

    // MVP: fonte de produto via Open Food Facts
    const productRes = await axios.get(
      `https://world.openfoodfacts.org/api/v0/product/${barcode}.json`,
      { timeout: 1300 }
    );

    const productName =
      productRes.data?.product?.product_name || `Produto ${barcode}`;

    // MVP: preços simulados enquanto integra 3 fontes reais
    const prices = [
      Math.max(userPrice * 0.82, 1),
      Math.max(userPrice * 0.93, 1),
      Math.max(userPrice * 1.07, 1)
    ];

    const averagePrice =
      Math.round((prices.reduce((sum, p) => sum + p, 0) / prices.length) * 100) /
      100;
    const status = classifyPrice(userPrice, averagePrice);
    const differencePercent = calculateDifferencePercent(userPrice, averagePrice);

    return {
      statusCode: 200,
      headers: {
        "content-type": "application/json"
      },
      body: JSON.stringify({
        name: productName,
        barcode,
        user_price: userPrice,
        average_price: averagePrice,
        status,
        difference_percent: differencePercent,
        sampled_prices: prices.map((p) => Number(p.toFixed(2)))
      })
    };
  } catch (error) {
    const statusCode = error.response?.status || 500;

    return {
      statusCode,
      body: JSON.stringify({
        error: "Falha ao consultar produto/preços",
        details: error.message
      })
    };
  }
};


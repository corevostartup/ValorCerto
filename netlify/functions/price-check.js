const axios = require("axios");

function corsHeaders(extra = {}) {
  return {
    "access-control-allow-origin": "*",
    "access-control-allow-methods": "POST, OPTIONS",
    "access-control-allow-headers": "Content-Type",
    ...extra
  };
}

function classifyPrice(userPrice, averagePrice) {
  if (userPrice > averagePrice * 1.1) return "caro";
  if (userPrice < averagePrice * 0.9) return "barato";
  return "ok";
}

function calculateDifferencePercent(userPrice, averagePrice) {
  return Math.round(((userPrice - averagePrice) / averagePrice) * 100);
}

/** Referência MVP: média quando não há preço informado pelo usuário */
function basePriceFromBarcode(barcode) {
  const s = String(barcode);
  let h = 0;
  for (let i = 0; i < s.length; i += 1) {
    h = (h * 31 + s.charCodeAt(i)) >>> 0;
  }
  const cents = (h % 2500) + 500;
  return cents / 100;
}

exports.handler = async function handler(event) {
  if (event.httpMethod === "OPTIONS") {
    return {
      statusCode: 204,
      headers: corsHeaders()
    };
  }

  if (event.httpMethod !== "POST") {
    return {
      statusCode: 405,
      headers: corsHeaders({ "content-type": "application/json" }),
      body: JSON.stringify({ error: "Use POST" })
    };
  }

  let payload;
  try {
    payload = JSON.parse(event.body || "{}");
  } catch {
    return {
      statusCode: 400,
      headers: corsHeaders({ "content-type": "application/json" }),
      body: JSON.stringify({ error: "Corpo JSON inválido" })
    };
  }

  // Barcode: string ou número (ex.: EAN-13 no JSON).
  // user_price: opcional — omitido, null, "" ou ≤0 ⇒ só calcula média de referência (sem comparação).
  const barcode = payload.barcode != null ? String(payload.barcode).trim() : "";
  const userPriceCandidate = payload.user_price;
  // Preço do utilizador só conta se for um número > 0; omitir, null ou 0 = só média.
  const hasUserPrice =
    userPriceCandidate !== undefined &&
    userPriceCandidate !== null &&
    !Number.isNaN(Number(userPriceCandidate)) &&
    Number(userPriceCandidate) > 0;
  const userPrice = hasUserPrice ? Number(userPriceCandidate) : null;

  if (!barcode) {
    return {
      statusCode: 400,
      headers: corsHeaders({ "content-type": "application/json" }),
      body: JSON.stringify({
        error: "Informe barcode. user_price é opcional."
      })
    };
  }

  /** Nunca falhar a consulta só porque o Open Food Facts falhou (rede, 404, rate limit). */
  let productName = `Produto ${barcode}`;
  try {
    const url = `https://world.openfoodfacts.org/api/v0/product/${encodeURIComponent(
      String(barcode)
    )}.json`;
    const productRes = await axios.get(url, {
      timeout: 8000,
      validateStatus: () => true
    });
    if (
      productRes.status === 200 &&
      productRes.data &&
      productRes.data.status === 1 &&
      productRes.data.product &&
      productRes.data.product.product_name
    ) {
      const n = String(productRes.data.product.product_name).trim();
      if (n) productName = n;
    }
  } catch {
    // timeout, DNS, etc. — mantém nome genérico e segue com média local
  }

  try {
    let prices;

    if (hasUserPrice) {
      prices = [
        Math.max(userPrice * 0.82, 1),
        Math.max(userPrice * 0.93, 1),
        Math.max(userPrice * 1.07, 1)
      ];
    } else {
      const base = basePriceFromBarcode(barcode);
      prices = [
        Math.max(base * 0.88, 1),
        Math.max(base, 1),
        Math.max(base * 1.12, 1)
      ];
    }

    const averagePrice =
      Math.round((prices.reduce((sum, p) => sum + p, 0) / prices.length) * 100) /
      100;

    let compared = false;
    let status = null;
    let differencePercent = null;

    if (hasUserPrice) {
      compared = true;
      status = classifyPrice(userPrice, averagePrice);
      differencePercent = calculateDifferencePercent(userPrice, averagePrice);
    }

    return {
      statusCode: 200,
      headers: corsHeaders({
        "content-type": "application/json"
      }),
      body: JSON.stringify({
        name: productName,
        barcode,
        compared,
        user_price: hasUserPrice ? userPrice : null,
        average_price: averagePrice,
        status,
        difference_percent:
          typeof differencePercent === "number"
            ? differencePercent
            : null,
        sampled_prices: prices.map((p) => Number(p.toFixed(2)))
      })
    };
  } catch (error) {
    return {
      statusCode: 500,
      headers: corsHeaders({ "content-type": "application/json" }),
      body: JSON.stringify({
        error: "Falha ao calcular resposta",
        details: error.message
      })
    };
  }
};

# FAAR POS — Dynamic Taxation & GST Engine

## 1. Pure Dart Financial Mathematics
All monetary calculations in FAAR POS are performed using `package:decimal` and `package:rational`. Floating-point arithmetic (`double`) is strictly prohibited.

---

## 2. Tax Computation Formulas

### 2.1 Tax-Exclusive Pricing (GST Added to Base)
Given:
* $P_{base}$ = Base Price
* $Q$ = Quantity
* $D$ = Discount Amount
* $R_{total}$ = Total GST Rate % (e.g. 18.0)

$$Taxable\ Amount = (P_{base} \times Q) - D$$

#### Intra-State Sale (Buyer State == Seller State or null):
$$CGST = Taxable\ Amount \times \frac{R_{total} / 2}{100}$$
$$SGST = Taxable\ Amount \times \frac{R_{total} / 2}{100}$$
$$Total\ Tax = CGST + SGST$$
$$Grand\ Total = Taxable\ Amount + Total\ Tax$$

#### Inter-State Sale (Buyer State != Seller State):
$$IGST = Taxable\ Amount \times \frac{R_{total}}{100}$$
$$Total\ Tax = IGST$$
$$Grand\ Total = Taxable\ Amount + Total\ Tax$$

---

### 2.2 Tax-Inclusive Pricing (GST Extracted from Gross Price)
Given $P_{gross}$ (Gross Sticker Price):

$$Taxable\ Amount = \frac{(P_{gross} \times Q) - D}{1 + \frac{R_{total}}{100}}$$
$$Total\ Tax = ((P_{gross} \times Q) - D) - Taxable\ Amount$$

---

## 3. Supported Standard Slabs
* **0% (Exempt):** Basic food grains, fresh produce.
* **5% (Concessional):** Essential packaged goods.
* **12% (Standard Lower):** Construction materials, processed foods.
* **18% (Standard Higher):** Brass fixtures, glass architectural panels, general retail.
* **28% (Luxury / De-merit):** High-end fixtures, specialized equipment.

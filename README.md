Vault Protocol - ERC4626 Project Funding Platform





Hello everyone !! Welcome to my first ever web3 project HashFox-Protocol !!

Don't judge me it's the first one lol

Overview : 

The Vault contract is a decentralized platform for funding artistic/business projects through tokenized shares, using collateralized loans and investor shares. 

It enables project creators (artists) to raise funds, issue shares, and distribute returns to investors.

The contract also handles collateral deposits, liquidation, and finalization of projects.


Key Components : 

ERC4626: Implements the ERC4626 standard for tokenized vaults, enabling efficient fund management and share issuance.

Access Control: Utilizes roles (Admin, Artist, Guarantor) to control access to critical actions.

Collateral System: A loan-to-value (LTV) ratio system ensures projects are adequately collateralized. Guarantors deposit collateral and can trigger liquidation if collateral falls below a threshold.

Investor Shares: Investors receive shares based on their investment, which can be redeemed after project finalization.


Key Features :

Project Creation:

Admins create projects by specifying funding goals, projected returns, LTV/LLTV ratios, and deadlines. Artists are assigned roles.

Investment:

Investors deposit stablecoins into the project vault, receiving ERC4626 shares.

Investments are tracked, and shares are issued in proportion to the amount invested.

Once the funding goal is met, the artist receives the funds.

Collateral Management:

Guarantors deposit collateral before investments are accepted.

If the project fails (e.g., insufficient collateral or revenue), the collateral is liquidated, and refunds are issued to investors.

Project Finalization:

Once funding is complete, the artist can finalize the project by ensuring returns meet a 95% threshold of projected returns.

Investors can withdraw their share of the revenue after project finalization.

Liquidation:

If collateral value falls below the liquidation threshold (based on the LLTV ratio), the guarantor’s collateral is liquidated and refunded to investors.


Use Cases : 

Artists: Raise funds for their projects by offering equity through tokenized shares.

Investors: Invest in artistic projects and earn a share of the returns.

Guarantors: Provide collateral to secure the funding and help protect investors in case of failure.

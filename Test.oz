functor
import
    System
    BaseModule at './src/BaseModule.ozf'
    FileHelper at './library/FileHelperModule.ozf'
define

    % Test des fonctions de base

    % Charge les données
    GenesisState = {FileHelper.readGenesisFromFile './data/genesis.txt'}
    Transactions = {FileHelper.readTransactionsFromFile './data/transactions.txt'}

    % Affiche le genesis
    {System.showInfo "=== GENESIS STATE ==="}
    {System.show GenesisState}

    % Affiche les transactions brutes
    {System.showInfo "=== TRANSACTIONS BRUTES ==="}
    {System.show Transactions}

    % Execute la blockchain
    FinalState FinalBlockchain
    {BaseModule.executeBlockchain GenesisState Transactions FinalState FinalBlockchain}

    % Affiche l'état final
    {System.showInfo "=== FINAL STATE ==="}
    {System.show FinalState}

    % Affiche la blockchain finale
    {System.showInfo "=== FINAL BLOCKCHAIN ==="}
    {System.show FinalBlockchain}

end
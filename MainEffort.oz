functor
import
    Application
    System
    BaseModule at './ExtensionEffort.ozf'
    FileHelper at './library/FileHelperModule.ozf'
define
    GenesisState = {FileHelper.readGenesisFromFile './data/genesis.txt'}
    Transactions = {FileHelper.readTransactionsFromFile './data/transactions.txt'}
    FinalState FinalBlockchain
in
    {BaseModule.executeBlockchain GenesisState Transactions FinalState FinalBlockchain}
    {System.showInfo "Final State:"}
    {System.show FinalState}
    {System.showInfo "Secret is:"}
    {System.showInfo {BaseModule.decode FinalBlockchain}}
end
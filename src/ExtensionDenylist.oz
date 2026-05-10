functor
import 
    System
export
    decode:Decode
    executeBlockchain:ExecuteBlockchain
define
    
    %% PUT ANY AUXILIARY/HELPER FUNCTIONS THAT YOU NEED

    %% STUDENT START: Aurelle Awountsa

    % Fonction de puissance
    fun{Puissance Base Exposant}
        if Exposant == 0 then 1
        else Base * {Puissance Base Exposant - 1}
        end
    end

    % Nombre de chiffres d'un entier
    fun{NbChiffre N}
        if N < 10 then 1
        else 1 + {NbChiffre N div 10} 
        end
    end

    % Calcul de l'effort d'une transactions
    fun{SomPuissance Len I}
        if I >=Len then 0
        else {Puissance 2 I} + {SomPuissance Len I + 1}
        end
    end

    % Calculons l'effort d'une transactions
    fun {CalEffort T}
        Len = {NbChiffre T.value}
    in {SomPuissance Len 0}
    end
    
    % Somme des hashes de toutes les transactions pour hashage de fonctions
    fun {SomHashTransaction Transactions}
        case Transactions
        of nil then 0
        [] H|Rest then H.hash + {SomHashTransaction Rest}
        end
    end

% 2.1.2 Fonction de hashage
    fun {HashTransaction T}
        (T.nonce + T.sender + T.receiver + T.value) mod 1000000
    end

        % Hashage du bloc
    fun{HashBlock B}
        (B.number + B.previousHash + {SomHashTransaction B.transactions}) mod 1000000
    end
% 2.1.4 Validation d’une transaction

    % vérifie si l'utilisateur existe
    fun {UserExiste State UserId}
        {HasFeature State UserId}
    end

    % Nonce de l'utilisateur
    fun {GetNonce State UserId}
        if {UserExiste State UserId} then
            State.UserId.nonce
        else 0
        end
    end

    fun{GetBalance State UserId}
        if {HasFeature State UserId} then
            State.UserId.balance
        else 0
        end
    end
    % met à jour ou crée un utilisateur dans l'état
    fun{UpdateUser State UserId NewBalance NewNonce}
        UpdatedUser = user(balance:NewBalance nonce:NewNonce)
    in 
        {AdjoinAt State UserId UpdatedUser}
    end

    % Applique une transaction valide à l'état
    fun{ApplyTransaction State T}
        SenderBalance = {GetBalance State T.sender}
        ReceiverBalance = {GetBalance State T.receiver}
        SenderNonce = {GetNonce State T.sender}
        NewSenderBalance = SenderBalance - T.value
        NewReceiverBalance = ReceiverBalance + T.value
        NewSenderNonce = SenderNonce + 1
        StateAfterSender = {UpdateUser State T.sender NewSenderBalance NewSenderNonce}
    in
        {UpdateUser StateAfterSender T.receiver NewReceiverBalance {GetNonce StateAfterSender T.receiver}}
    end
     

    % Validation de la transaction
    fun{TransactionOk T State}
        NonceOk = (T.nonce == {GetNonce State T.sender} + 1)
        HashOk = (T.hash == {HashTransaction T})
        SenderOk = ({GetBalance State T.sender} >= T.value)
        ValueOk = (T.value >= 0)
        MaxEffortOk = (T.max_effort >= 0)
        EffortOk = (T.effort =< T.max_effort)
    in 
        NonceOk andthen HashOk andthen SenderOk andthen ValueOk 
        andthen MaxEffortOk andthen EffortOk
    end

    % Effort d'une liste de transaction
    fun {TotalEffort ListeTransaction}
        case ListeTransaction
        of nil then 0
        [] FirstTx | RestTxs then
            FirstTx.effort + {TotalEffort RestTxs}
        end
    end

    % Vérifie si toutes les transactions d'un bloc sont Ok
    fun{AllTransactionOk ListeTransaction State}
        case ListeTransaction
        of nil then true
        [] FirstTx | RestTxs then
            if {TransactionOk FirstTx State} then
                {AllTransactionOk RestTxs State}
            else false
            end
        end
    end

    % Regroupe les transactions par numéro de bloc
    fun{GroupByBlock ListeTransaction BlockNumber}
        case ListeTransaction
        of nil then nil#nil 
        [] FirstTx | RestTxs then
            if FirstTx.block_number == BlockNumber then
                CurrentBlock#Remaining = {GroupByBlock RestTxs BlockNumber}
            in (FirstTx | CurrentBlock) # Remaining
            else nil # ListeTransaction 
            end
        end
    end
    % Verifie si un utilisateur est dans la denylist
    fun {IsBlacklisted  State UserId}
        {Member UserId State.denylist}
    end

    % Ajoute un utilisateur a la denylist
    fun {AddToDenylist State UserId}
        {AdjoinAt State denylist UserId|State.denylist}
    end

    % Compte combien de fois UserId apparait dans une liste de transactions
    fun {CountSenderTxs Txlist UserId}
        case Txlist
        of nil then 0
        [] FirstTx|RestTxs then 
            if FirstTx.sender == UserId then
                1 + {CountSenderTxs RestTxs UserId}
            else
                {CountSenderTxs RestTxs UserId}
            end
        end
    end

    % Construit la denylist a partir de toutes les transactions d'un bloc
    fun {UpdateDenylist TxList State}
        Senders = {Map TxList fun {$ Tx} Tx.sender end}
        UniqueSenders = {FoldL Senders
            fun {$ Acc S}
                if {Member S Acc} then Acc
                else S|Acc
                end
            end
            nil
        }
    in
        {FoldL UniqueSenders
            fun {$ AccState Sender}
                if {CountSenderTxs TxList Sender} >= 3 then
                    {AddToDenylist AccState Sender}
                else
                    AccState
                end
            end
            State
        }
    end

    % Ajout d'une transaction valideà un bloc
    fun{FiltreTransaction ListeTransaction State CurrentEffort}
        case ListeTransaction
        of nil then nil # State
        [] FirstTx | RestTxs then
            TransactionEffort = {AdjoinAt FirstTx effort {CalEffort FirstTx}}
            NewEffort = CurrentEffort + TransactionEffort.effort
        in 
            % On verifie d'abord si le sender est blackliste
            if {IsBlacklisted State TransactionEffort.sender} then
                {FiltreTransaction RestTxs State CurrentEffort}
            elseif {TransactionOk TransactionEffort State} andthen NewEffort =< 300 then
                NewState = {ApplyTransaction State TransactionEffort}
                ValidTxs#FinalState = {FiltreTransaction RestTxs NewState NewEffort}
            in 
                (TransactionEffort | ValidTxs) # FinalState
            else 
                {FiltreTransaction RestTxs State CurrentEffort}
            end
        end
    end

    % Crée un bloc à partir d'une liste de transactions valides
    fun{CreeBlock ValidTxs BlockNumber PreBlock}
        IncompletBlock = block( number: BlockNumber previousHash: PreBlock.hash transactions: ValidTxs hash: 0)
        FinalHash = {HashBlock IncompletBlock}
    in  {AdjoinAt IncompletBlock hash FinalHash}
    end

    %Traiter tous les blocs de manière récursive 
    fun{ProcessBlocks ListeTransaction State PreBlock BlockNumber}
        case ListeTransaction
        of nil then State # nil
        [] _|_ then
            CurrentTxs # RestTxs = {GroupByBlock ListeTransaction BlockNumber}
            % Filtrer les transactions AVANT de mettre a jour la denylist
            ValidTxs # NewState = {FiltreTransaction CurrentTxs State 0}
            % Mettre a jour la denylist APRES avoir traite le bloc
            NewStateWithDenylist = {UpdateDenylist CurrentTxs NewState}
            NewBlock = {CreeBlock ValidTxs BlockNumber PreBlock}
            FinalState#RestChain = {ProcessBlocks RestTxs NewStateWithDenylist NewBlock BlockNumber+1}
        in FinalState#(NewBlock|RestChain)
        end
    end
    % vérifie si le bloc est Ok
    fun{BlockOk  Block PreBlock State}
        NumberOk = (Block.number == PreBlock.number + 1)
        PreviousHashOk = (Block.previousHash == PreBlock.hash)
        HashOk = (Block.hash == {HashBlock Block})
        AllTxsOk = {AllTransactionOk Block.transactions State}
        EffortOk = ({TotalEffort Block.transactions} =< 300)
    in
        NumberOk andthen PreviousHashOk andthen HashOk andthen AllTxsOk andthen EffortOk
    end 

    fun {ConvertirGenesis Genesis}
        Adresses = {Arity Genesis}
        BaseState = {FoldL Adresses
            fun {$ EtatAcc Adresse}
                {AdjoinAt EtatAcc Adresse user(balance:Genesis.Adresse nonce:0)}
            end
            state()
        }
    in
        {AdjoinAt BaseState denylist nil}
    end

    %% STUDENT END

    %% STUDENT START: CRISOSTOMO Gerald
    %declare 
    fun {Chiffres N Acc}
        if N < 10 then N | Acc
        else
            {Chiffres N div 10 (N mod 10) | Acc}
        end
    end

    fun {Paires Chiffres}
        case Chiffres 
            of nil then nil
            [] _|nil then nil
            [] Chif1|Chif2|Rest then 
                (Chif1 * 10 + Chif2) | {Paires Rest}
            end
    end

    fun {Convert NombrePair}
        case NombrePair
        of 10 then a
        [] 11 then b
        [] 12 then c
        [] 13 then d
        [] 14 then e
        [] 15 then f
        [] 16 then g
        [] 17 then h
        [] 18 then i
        [] 19 then j
        [] 20 then k
        [] 21 then l
        [] 22 then m
        [] 23 then n
        [] 24 then o
        [] 25 then p
        [] 26 then q
        [] 27 then r
        [] 28 then s
        [] 29 then t
        [] 30 then u
        [] 31 then v
        [] 32 then w
        [] 33 then x
        [] 34 then y
        [] 35 then z
        [] 36 then ' '
        end
    end


    fun {TraiterPair X}
        Nombre = X mod 37
        NombreFinal = if Nombre < 10 then 36 else Nombre end
    in
        {Convert NombreFinal}
    end


    fun {PairesToString Paires}
        case Paires
        of nil then ""
        [] H|T then
            {Atom.toString {TraiterPair H}} # {PairesToString T}
        end
    end

    
    %% STUDENT END 



    %% Return a string representation of the secret
    fun {Decode Blockchain}
        %% STUDENT START: CRISOSTOMO Gerald
        case Blockchain 
            of nil then ""
            [] Block|Rest then
                ChiffresHash = {Chiffres Block.hash nil}
                PairesHash = {Paires ChiffresHash}
                StringBloc = {PairesToString PairesHash}
        in
            {VirtualString.toString StringBloc # {Decode Rest}}
        end

        %% STUDENT END
    end


    % This procedure is the starting point of the execution
    % The GenesisState and the Transactions are given as input and the function is expected to bound the FinalState and the FinalBlockchain to their respective final values.
    proc {ExecuteBlockchain GenesisState Transactions FinalState FinalBlockchain}
        %% STUDENT START: Aurelle Awountsa
        EtatInitial = {ConvertirGenesis GenesisState}
        GenesisBlock = block(number: ~1 previousHash: 0 transactions: nil hash: 0)
        
        ResultState # ResultChain = {ProcessBlocks Transactions EtatInitial GenesisBlock 0}    
    in
        FinalState = ResultState
        FinalBlockchain = ResultChain
        %% STUDENT END
    end 
end

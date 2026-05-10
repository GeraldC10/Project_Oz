functor
export
    decode:Decode
    executeBlockchain:ExecuteBlockchain
define

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

    % Calcul de l'effort d'une transaction
    fun{SomPuissance Len I}
        if I >= Len then 0
        else {Puissance 2 I} + {SomPuissance Len I + 1}
        end
    end

    % Calculons l'effort d'une transaction
    fun {CalEffort T}
        Len = {NbChiffre T.value}
    in {SomPuissance Len 0}
    end

    % Somme des hashes de toutes les transactions
    fun {SomHashTransaction Transactions}
        case Transactions
        of nil then 0
        [] H|Rest then H.hash + {SomHashTransaction Rest}
        end
    end

    % Hash d'une transaction
    fun {HashTransaction T}
        (T.nonce + T.sender + T.receiver + T.value) mod 1000000
    end

    % Hash d'un bloc
    fun{HashBlock B}
        (B.number + B.previousHash + {SomHashTransaction B.transactions}) mod 1000000
    end

    % Verifie si un utilisateur existe
    fun {UserExiste State UserId}
        {HasFeature State UserId}
    end

    % Nonce d'un utilisateur
    fun {GetNonce State UserId}
        if {UserExiste State UserId} then
            State.UserId.nonce
        else 0
        end
    end

    % Solde d'un utilisateur
    fun{GetBalance State UserId}
        if {HasFeature State UserId} then
            State.UserId.balance
        else 0
        end
    end

    % Met a jour ou cree un utilisateur dans l'etat
    fun{UpdateUser State UserId NewBalance NewNonce}
        UpdatedUser = user(balance:NewBalance nonce:NewNonce)
    in 
        {AdjoinAt State UserId UpdatedUser}
    end

    % EXTENSION : Applique une transaction valide a l'etat
    % Le cout de l'effort est deduit du solde du sender en plus du montant
    fun{ApplyTransaction State T}
        SenderBalance      = {GetBalance State T.sender}
        ReceiverBalance    = {GetBalance State T.receiver}
        SenderNonce        = {GetNonce State T.sender}
        NewSenderBalance   = SenderBalance - T.value - T.effort
        NewReceiverBalance = ReceiverBalance + T.value
        NewSenderNonce     = SenderNonce + 1
        StateAfterSender   = {UpdateUser State T.sender NewSenderBalance NewSenderNonce}
    in
        {UpdateUser StateAfterSender T.receiver NewReceiverBalance {GetNonce StateAfterSender T.receiver}}
    end

    % EXTENSION : Validation d'une transaction
    % Le sender doit avoir assez de fonds pour payer value + effort
    fun{TransactionOk T State}
        NonceOk     = (T.nonce == {GetNonce State T.sender} + 1)
        HashOk      = (T.hash == {HashTransaction T})
        SenderOk    = ({GetBalance State T.sender} >= T.value + T.effort)
        ValueOk     = (T.value >= 0)
        MaxEffortOk = (T.max_effort >= 0)
        EffortOk    = (T.effort =< T.max_effort)
    in
        NonceOk andthen HashOk andthen SenderOk andthen ValueOk
        andthen MaxEffortOk andthen EffortOk
    end

    % Effort total d'une liste de transactions
    fun {TotalEffort ListeTransaction}
        case ListeTransaction
        of nil then 0
        [] FirstTx | RestTxs then
            FirstTx.effort + {TotalEffort RestTxs}
        end
    end

    % Verifie si toutes les transactions d'un bloc sont valides
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

    % Regroupe les transactions par numero de bloc
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
    fun {IsBlacklisted State UserId}
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

    % Met a jour la denylist apres chaque bloc
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

    % Filtre les transactions valides d'un bloc
    fun{FiltreTransaction ListeTransaction State CurrentEffort}
        case ListeTransaction
        of nil then nil # State
        [] FirstTx | RestTxs then
            TransactionEffort = {AdjoinAt FirstTx effort {CalEffort FirstTx}}
            NewEffort = CurrentEffort + TransactionEffort.effort
        in 
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

    % Cree un bloc a partir d'une liste de transactions valides
    fun{CreeBlock ValidTxs BlockNumber PreBlock}
        IncompletBlock = block(
            number:       BlockNumber
            previousHash: PreBlock.hash
            transactions: ValidTxs
            hash:         0
        )
        FinalHash = {HashBlock IncompletBlock}
    in
        {AdjoinAt IncompletBlock hash FinalHash}
    end

    % Traite tous les blocs de maniere recursive
    fun{ProcessBlocks ListeTransaction State PreBlock BlockNumber}
        case ListeTransaction
        of nil then State # nil
        [] _|_ then
            CurrentTxs # RestTxs       = {GroupByBlock ListeTransaction BlockNumber}
            ValidTxs # NewState        = {FiltreTransaction CurrentTxs State 0}
            NewStateWithDenylist       = {UpdateDenylist CurrentTxs NewState}
            NewBlock                   = {CreeBlock ValidTxs BlockNumber PreBlock}
            FinalState#RestChain       = {ProcessBlocks RestTxs NewStateWithDenylist NewBlock BlockNumber+1}
        in FinalState#(NewBlock|RestChain)
        end
    end

    % Convertit le genesis en etat initial
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

    fun {Decode Blockchain}
        case Blockchain 
        of nil then ""
        [] Block|Rest then
            ChiffresHash = {Chiffres Block.hash nil}
            PairesHash   = {Paires ChiffresHash}
            StringBloc   = {PairesToString PairesHash}
        in
            {VirtualString.toString StringBloc # {Decode Rest}}
        end
    end

    %% STUDENT END

    proc {ExecuteBlockchain GenesisState Transactions FinalState FinalBlockchain}
        %% STUDENT START: Aurelle Awountsa
        EtatInitial = {ConvertirGenesis GenesisState}
        GenesisBlock = block(number:~1 previousHash:0 transactions:nil hash:0)
        ResultState#ResultChain = {ProcessBlocks Transactions EtatInitial GenesisBlock 0}
    in
        FinalState      = ResultState
        FinalBlockchain = ResultChain
        %% STUDENT END
    end

end
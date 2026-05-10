functor
export
    decode:Decode
    executeBlockchain:ExecuteBlockchain
    biggestSenders:BiggestSenders
    receivedMost:ReceivedMost
    moneyPeak:MoneyPeak
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
% 2.1.4 Validation d'une transaction

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
    in NonceOk andthen HashOk andthen SenderOk andthen ValueOk 
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

    % Ajout d'une transaction valideà un bloc
    fun{FiltreTransaction ListeTransaction State CurrentEffort}
        case ListeTransaction
        of nil then nil # State
        [] FirstTx | RestTxs then
            TransactionEffort = {AdjoinAt FirstTx effort {CalEffort FirstTx}}
            NewEffort = CurrentEffort + TransactionEffort.effort
        in 
            if {TransactionOk TransactionEffort State} andthen NewEffort =< 300 then
                NewState = {ApplyTransaction State TransactionEffort}
                ValidTxs # FinalState = {FiltreTransaction RestTxs NewState NewEffort}
            in (TransactionEffort | ValidTxs) # FinalState
            else {FiltreTransaction RestTxs State CurrentEffort}
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
            ValidTxs # NewState = {FiltreTransaction CurrentTxs State 0}
            NewBlock = {CreeBlock ValidTxs BlockNumber PreBlock}
            FinalState#RestChain = {ProcessBlocks RestTxs NewState NewBlock BlockNumber+1}
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
    in
    {FoldL Adresses
        fun {$ EtatAcc Adresse}
            {AdjoinAt EtatAcc Adresse user(balance:Genesis.Adresse nonce:0)}
        end
        state()
    }
    end

    %% STUDENT END

    %% STUDENT START: CRISOSTOMO Gerald

    %Convertit un entier en liste de chiffres ex: 256424 -> [2 5 6 4 2 4]
    fun {Chiffres N Acc}
        if N < 10 then N | Acc
        else
            {Chiffres N div 10 (N mod 10) | Acc}
        end
    end

    %Regroupe les chiffres en paires ex: [2 5 6 4 2 4] -> [25 64 24]
    fun {Paires Chiffres}
        case Chiffres 
            of nil then nil
            [] _|nil then nil
            [] Chif1|Chif2|Rest then 
                (Chif1 * 10 + Chif2) | {Paires Rest}
            end
    end

    %Convertit un nombre (10-36) en lettre selon le tableau de Sharelock
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

    %Applique mod 37 sur une paire, remplace par 36 si < 10, puis convertit en lettre
    fun {TraiterPair X}
        Nombre = X mod 37
        NombreFinal = if Nombre < 10 then 36 else Nombre end
    in
        {Convert NombreFinal}
    end

    %Transforme une liste de paires en string en appliquant TraiterPair sur chaque element
    fun {PairesToString Paires}
        case Paires
        of nil then ""
        [] H|T then
            {Atom.toString {TraiterPair H}} # {PairesToString T}
        end
    end

    %Extrait toutes les transactions de tous les blocs en une liste plate
    fun {GetAllTransactions Blockchain}
        case Blockchain
        of nil then nil
        [] Block|Rest then
            {Append Block.transactions {GetAllTransactions Rest}}
        end
    end

    % Cherche le compteur d'un sender dans la liste, retourne 0 si absent
    fun {FindSender Counts Sender}
        case Counts
        of nil then 0
        [] (S#C)|Rest then
            if S == Sender then C
            else {FindSender Rest Sender}
            end
        end
    end

    % Incremente le compteur du sender, l'ajoute avec 1 s'il est nouveau
    fun {Update Counts Sender}
        case Counts
        of nil then [Sender#1]
        [] (S#C)|Rest then
            if S == Sender then (S#(C+1))|Rest
            else (S#C)|{Update Rest Sender}
            end
        end
    end

    % Compte le nombre de transactions envoyees par chaque sender
    fun {CountSenders Transactions Counts}
        case Transactions
        of nil then Counts
        [] T|Rest then 
            {CountSenders Rest {Update Counts T.sender}}
        end
    end

    % Insere un element dans une liste triee par ordre decroissant, egalite -> id croissant
    fun {Insert Elem Liste}
        case Liste
        of nil then [Elem]
        [] (S#C)|Rest then
            Sender#Count = Elem
        in
            if Count > C then Elem|Liste
            elseif Count == C andthen Sender < S then Elem|Liste
            else (S#C)|{Insert Elem Rest}
            end
        end
    end

    % Tri par insertion sur une liste de paires id#valeur
    fun {Sort List}
        case List
        of nil then nil
        [] H|Rest then
            {Insert H {Sort Rest}}
        end
    end

    % Retourne les N premiers elements d'une liste
    fun {FirstN Liste N}
        if N =< 0 then nil
        else
            case Liste
            of nil then nil
            [] H|Rest then
                if N == 0 then nil
                else H|{FirstN Rest N-1}
                end
            end
        end
    end

    % Retourne les N senders ayant fait le plus de transactions, ~1 si N <= 0
    fun {BiggestSenders Blockchain N}
        if N =< 0 then ~1
        else
            Transactions = {GetAllTransactions Blockchain}
            Counts = {CountSenders Transactions nil}
            Tries = {Sort Counts}
        in
            {FirstN Tries N}
        end
    end

    % Additionne la valeur recue par chaque receiver, l'ajoute s'il est nouveau
    fun {UpdateReceiver Counts Receiver Value}
        case Counts
        of nil then [Receiver#Value]
        [] (R#C)|Rest then
            if R == Receiver then (R#(C+Value))|Rest
            else (R#C)|{UpdateReceiver Rest Receiver Value}
            end
        end
    end

    % Additionne les valeurs de toutes les transactions recues par chaque receiver
    fun {CountReceivers Transactions Counts}
        case Transactions
        of nil then Counts
        [] T|Rest then
            {CountReceivers Rest {UpdateReceiver Counts T.receiver T.value}}
        end
    end

    % Retourne les N receivers ayant recu le plus de valeur, ~1 si N <= 0
    fun {ReceivedMost Blockchain N}
        if N =< 0 then ~1
        else
            Transactions = {GetAllTransactions Blockchain}
            Counts = {CountReceivers Transactions nil}
            Sorted = {Sort Counts}
        in
            {FirstN Sorted N}
        end
    end

    % Met a jour le pic de solde d'un utilisateur si le nouveau solde est plus grand
    fun {UpdatePeak Peaks UserId Balance}
        case Peaks
        of nil then [UserId#Balance]
        [] (Id#Max)|Rest then
            if Id == UserId then
                if Balance > Max then (Id#Balance)|Rest
                else (Id#Max)|Rest
                end
            else (Id#Max)|{UpdatePeak Rest UserId Balance}
            end
        end
    end

    % Applique une transaction et met a jour les pics du sender et receiver
    fun {ApplyAndTrack T State Peaks}
        NewState = {ApplyTransaction State T}
        SenderBalance = {GetBalance NewState T.sender}
        ReceiverBalance = {GetBalance NewState T.receiver}
        PeaksAfterSender = {UpdatePeak Peaks T.sender SenderBalance}
        PeaksAfterReceiver = {UpdatePeak PeaksAfterSender T.receiver ReceiverBalance}
    in
        NewState#PeaksAfterReceiver
    end

    % Rejoue toutes les transactions en maintenant les pics de solde
    fun {TrackPeaks Transactions State Peaks}
        case Transactions
        of nil then Peaks
        [] T|Rest then
            NewState#NewPeaks = {ApplyAndTrack T State Peaks}
        in
            {TrackPeaks Rest NewState NewPeaks}
        end
    end

    % Parcourt les peaks et retourne l'utilisateur avec le solde max sous forme id#solde
    fun {FindMax Peaks CurrentMax}
        case Peaks
        of nil then CurrentMax
        [] (Id#Balance)|Rest then
            if Balance > CurrentMax.2 then
                {FindMax Rest Id#Balance}
            else
                {FindMax Rest CurrentMax}
            end
        end
    end

    % Retourne l'utilisateur ayant eu le solde le plus eleve sous forme id#solde
    fun {MoneyPeak Blockchain}
        Transactions = {GetAllTransactions Blockchain}
        Peaks = {TrackPeaks Transactions state() nil}
    in
        {FindMax Peaks 0#0}
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

    proc {ExecuteBlockchain GenesisState Transactions FinalState FinalBlockchain}
        %% STUDENT START: Aurelle Awountsa
    EtatInitial = {ConvertirGenesis GenesisState}
    GenesisBlock = block(number: ~1 previousHash: 0 transactions: nil hash: 0)
    ResultState # ResultChain = {ProcessBlocks Transactions EtatInitial GenesisBlock 0}    in
        FinalState = ResultState
        FinalBlockchain = ResultChain
        %% STUDENT END
    end 
end
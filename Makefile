OZ=ozc # OZ Compiler
OZE=ozengine # OZ Emulator
TEST_SRC=Test.oz
TEST_OZF=$(TEST_SRC:.oz=.ozf)

NOMA1=95942400
NOMA2=00002400
ZIP_NAME=$(NOMA1)_$(NOMA2).zip

# Fichiers sources
BASE_SRC=src/BaseModule.oz
HELPER_SRC=library/FileHelperModule.oz
MAIN_SRC=Main.oz

# Fichiers compilés (foncteurs)
BASE_OZF=$(BASE_SRC:.oz=.ozf)
EFFORT_SRC=src/ExtensionEffort.oz
DENYLIST_SRC=src/ExtensionDenylist.oz
HELPER_OZF=$(HELPER_SRC:.oz=.ozf)
MAIN_OZF=$(MAIN_SRC:.oz=.ozf)

# Fichiers compilés
BASE_OZF=$(BASE_SRC:.oz=.ozf)
EFFORT_OZF=$(EFFORT_SRC:.oz=.ozf)
DENYLIST_OZF=$(DENYLIST_SRC:.oz=.ozf)
HELPER_OZF=$(HELPER_SRC:.oz=.ozf)
MAIN_OZF=$(MAIN_SRC:.oz=.ozf)
	
# Cible par défaut : tout compiler
all: $(BASE_OZF) $(HELPER_OZF) $(MAIN_OZF)

# Règle pour compiler les fichiers .oz en .ozf
%.ozf: %.oz
	$(OZ) -c $< -o $@

# Dépendances spécifiques (Main a besoin des modules pour être testé, 
# même si ozc -c ne vérifie pas les imports à la compilation)
$(MAIN_OZF): $(MAIN_SRC) $(BASE_OZF) $(HELPER_OZF)
	$(OZ) -c $(MAIN_SRC) -o $(MAIN_OZF)

# Commande pour nettoyer les fichiers compilés
clean:
	rm -f $(BASE_OZF) $(HELPER_OZF) $(MAIN_OZF)

# Commande pour exécuter le programme (exemple avec arguments)
run: all
	$(OZE) $(MAIN_OZF)

# Executer avec ExtensionDenylist
run-denylist: $(DENYLIST_OZF) $(HELPER_OZF)
	cp $(DENYLIST_OZF) $(BASE_OZF)
	$(OZE) $(MAIN_OZF)
	cp $(BASE_OZF) $(BASE_OZF)

# Executer avec ExtensionEffort
run-effort: $(EFFORT_OZF) $(HELPER_OZF) $(MAIN_OZF)
	cp $(EFFORT_OZF) $(BASE_OZF)
	$(OZE) $(MAIN_OZF)

# Nettoyer
clean:
	rm -f $(BASE_OZF) $(EFFORT_OZF) $(DENYLIST_OZF) $(HELPER_OZF) $(MAIN_OZF)


zip: clean
	@if [ ! -f "rapport.pdf" ]; then \
		echo "ERREUR : Le fichier 'rapport.pdf' est manquant à la racine !"; \
		exit 1; \
	fi
	zip -r $(ZIP_NAME) . -x "*.ozf" "*.git*" "*/.*" "Makefile"
	@echo "L'archive $(ZIP_NAME) a été créée avec succès."
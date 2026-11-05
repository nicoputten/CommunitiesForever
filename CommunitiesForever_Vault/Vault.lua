-- CommunitiesForever Vault (CF-84): only its SavedVariables, CommunitiesForeverVaultDB, in its own file
-- (WTF\Account\<account>\SavedVariables\CommunitiesForever_Vault.lua), which the uploader never reads. The guild code
-- and the guild member list for alts live here; CommunitiesForever reads and writes them (src/adapters/Vault.lua).
-- This file runs before the saved data loads: a first start keeps this empty table, later starts get the saved one.
CommunitiesForeverVaultDB = CommunitiesForeverVaultDB or {}

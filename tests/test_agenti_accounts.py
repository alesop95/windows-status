"""Verifica il passaggio di account distinti nel punto d'ingresso della macchina."""
import json
import os
import subprocess
import tempfile
import unittest
from pathlib import Path


@unittest.skipUnless(os.name == 'nt', 'Punto di ingresso Windows')
class AccountSelectionTests(unittest.TestCase):
    def test_machine_wrapper_forwards_typed_account_arrays(self):
        script = Path(__file__).resolve().parents[1] / 'scripts/Agenti.ps1'
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            tools = root / '.claude/templates/agenti-terminale/tools'
            tools.mkdir(parents=True)
            (tools / 'Installa-Agenti.ps1').write_text('''param([int[]]$Claude,[int[]]$Codex,[string]$Template,[switch]$NienteDaPreservare,[string[]]$PrefissiImpostazioni,[switch]$Verifica)
@{Claude=@($Claude);Codex=@($Codex);Verifica=[bool]$Verifica}|ConvertTo-Json -Compress
''', encoding='utf-8')
            runner = root / 'runner.ps1'
            runner.write_text("& $args[0] verifica -Template $args[1] -Claude @(4,5) -Codex @(6)\n", encoding='utf-8')
            result = subprocess.run(['powershell.exe', '-NoProfile', '-File', str(runner), str(script), str(root)],
                                    capture_output=True, timeout=30)
            self.assertEqual(result.returncode, 0, result.stderr.decode(errors='replace'))
            data = json.loads(result.stdout)
            self.assertEqual(data['Claude'], [4, 5])
            self.assertEqual(data['Codex'], [6])
            self.assertTrue(data['Verifica'])


if __name__ == '__main__':
    unittest.main()

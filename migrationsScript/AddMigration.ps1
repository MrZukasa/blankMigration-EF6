# Definisci i percorsi e altri parametri
$assemblyPath = "..."
$configPath = ".."
$projectDir = ".."
$csprojPath = '...'
$baseDir = "..."

# Costruisci il comando EF6
$efCommand = "ef6 migrations add IgnoreChanges --ignore-changes --json --assembly $assemblyPath --config $configPath --project-dir $projectDir"

# Esegui il comando EF6
$query = Invoke-Expression $efCommand

$jsonContent = $query -split "`n" | Where-Object { $_ -match '^\s*{' -or $_ -match '^\s*"' -or $_ -match '^\s*}' };

$result = $jsonContent -join "`n" | ConvertFrom-Json;

# Carica il file .csproj come XML
[xml]$csproj = Get-Content -Path $csprojPath

# Estrai i percorsi dai dati JSON
$migrationPath = $result.migration
$migrationDesignerPath = $result.migrationDesigner
$migrationResourcesPath = $result.migrationResources

# Ottieni i percorsi relativi
$relativeMigrationPath = [System.IO.Path]::GetRelativePath($baseDir, $migrationPath)
$relativeMigrationDesignerPath = [System.IO.Path]::GetRelativePath($baseDir, $migrationDesignerPath)
$relativeMigrationResourcesPath = [System.IO.Path]::GetRelativePath($baseDir, $migrationResourcesPath)

# Trova il nodo <ItemGroup> che contiene un elemento <Compile> con Include="ActivityListRepository.cs"
$itemGroupCs = $null
foreach ($itemGroup in $csproj.Project.ItemGroup) {
    foreach ($compile in $itemGroup.Compile) {
        if ($compile.Include -eq "ActivityListRepository.cs") {
            $itemGroupCs = $itemGroup
            break
        }
    }
    if ($itemGroupCs) { break }
}

# Trova il nodo <ItemGroup> che contiene un elemento <EmbeddedResource> con Include="Migrations\2014\12-Dec\201412201650195_InitialCreate.resx"
$itemGroupResx = $null
foreach ($itemGroup in $csproj.Project.ItemGroup) {
    foreach ($embeddedResource in $itemGroup.EmbeddedResource) {
        if ($embeddedResource.Include -eq "Migrations\2014\12-Dec\201412201650195_InitialCreate.resx") {
            $itemGroupResx = $itemGroup
            break
        }
    }
    if ($itemGroupResx) { break }
}

# Crea i nuovi nodi
$newCompileNode1 = $csproj.CreateElement("Compile")
$newCompileNode1.SetAttribute("Include", $relativeMigrationPath)

$newCompileNode2 = $csproj.CreateElement("Compile")
$newCompileNode2.SetAttribute("Include", $relativeMigrationDesignerPath)
$dependentUponNode1 = $csproj.CreateElement("DependentUpon")
$dependentUponNode1.InnerText = [System.IO.Path]::GetFileName($relativeMigrationPath)
$newCompileNode2.AppendChild($dependentUponNode1)

$newEmbeddedResourceNode = $csproj.CreateElement("EmbeddedResource")
$newEmbeddedResourceNode.SetAttribute("Include", $relativeMigrationResourcesPath)
$dependentUponNode2 = $csproj.CreateElement("DependentUpon")
$dependentUponNode2.InnerText = [System.IO.Path]::GetFileName($relativeMigrationPath)
$newEmbeddedResourceNode.AppendChild($dependentUponNode2)

# Aggiungi i nuovi nodi al <ItemGroup> corrispondente
$itemGroupCs.AppendChild($newCompileNode1) | Out-Null
$itemGroupCs.AppendChild($newCompileNode2) | Out-Null
$itemGroupResx.AppendChild($newEmbeddedResourceNode) | Out-Null

# Salva le modifiche nel file .csproj
$csproj.Save($csprojPath)

$updateCommand = '.\MSBuild\Current\Bin\MSBuild.exe $csprojPath -verbosity:quiet'

Invoke-Expression $updateCommand

ef6 database update --assembly $assemblyPath --config $configPath
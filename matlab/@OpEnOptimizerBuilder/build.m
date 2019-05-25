function opEnOptimizer = build(opEnBuilder)
%OPEN_GENERATE_CODE generates Rust code for a given parametric optimizer.
%
%In order to use this code generation function, you first need to create a
%configuration object, `opEnBuilder`. You can do so using
%`open_opEnBuilder`; you can then customize your configuration.
%
%For example:
% opEnBuilder = open_opEnBuilder();
% opEnBuilder.build_name = 'my_optimizer'
%
%Syntax:
% open_generate_code(opEnBuilder, u, p, cost, constraints)
% [cost_f, grad_f] = open_generate_code(opEnBuilder, u, p, cost, constraints)
%
%Input arguments:
% opEnBuilder     build configuration, generated by open_opEnBuilder
% u                decision variable as a casADi vector (casadi.SX.sym)
% p                parameter as a casADi vector (casadi.SX.sym)
% cost             cost function - a function of u and p - as a casADi function
% constraints      constraints on the decision variable, u, as an instnace 
%                  of `OpEnConstraints`
%
%Output arguments:
% cost_f           cost function as an instance of casADi's SXFunction
% grad_f           gradient of the cost function with respect to `u` - a
%                  function of `u` and `p` - as an instance of casADi's
%                  SXFunction
%
%See also
%OpEnConstraints, open_opEnBuilder

% -------------------------------------------------------------------------
% Prepare code generation 
% -------------------------------------------------------------------------

% Prepare destination folder; clean contents if it exists (calls mkdir)
clean_destination(opEnBuilder);

% Create Cargo.toml in destination project
open_generate_cargo(opEnBuilder);

% Move `icasadi` to destination 
destination_dir = fullfile(opEnBuilder.build_path, opEnBuilder.build_name);
copyfile(fullfile(matlab_open_root(), 'icasadi'), fullfile(destination_dir, 'icasadi'));



% -------------------------------------------------------------------------
% CasADi generates C files
% -------------------------------------------------------------------------

% Generate CasADi code (within the context of autogen_optimizer/icasadi)
casadi_codegen(opEnBuilder.sx_u, opEnBuilder.sx_p, opEnBuilder.cost, destination_dir);


% -------------------------------------------------------------------------
% RUST code generation
% -------------------------------------------------------------------------

% Copy head to main.rs into destination location
codegen_head(opEnBuilder);

main_file = fullfile(opEnBuilder.build_path, opEnBuilder.build_name, ...
    'src', 'main.rs');
fid_main = fopen(main_file, 'a+');

codegen_const(fid_main, opEnBuilder, opEnBuilder.sx_u, opEnBuilder.sx_p);
copy_into_main(fid_main, fullfile(matlab_open_root, 'matlab', ...
    'private', 'codegen_get_cache.txt'));
copy_into_main(fid_main, fullfile(matlab_open_root, 'matlab', ...
    'private', 'codegen_main_fn_def.txt'));
main1(fid_main, opEnBuilder);
copy_into_main(fid_main, fullfile(matlab_open_root, 'matlab', ...
    'private', 'codegen_main_2.txt'));
open_impose_bounds(fid_main, opEnBuilder.constraints)
copy_into_main(fid_main, fullfile(matlab_open_root, 'matlab', ...
    'private', 'codegen_main_3.txt'));
fclose(fid_main);

build_autogenerated_project(opEnBuilder);


% -------------------------------------------------------------------------
% Create OpEnOptimizer
% -------------------------------------------------------------------------
ip = opEnBuilder.udp_interface.bind_address;
port = opEnBuilder.udp_interface.port;
destination_dir = fullfile(opEnBuilder.build_path, opEnBuilder.build_name);
opEnOptimizer = OpEnOptimizer(ip, port, destination_dir, opEnBuilder.build_mode);

% -------------------------------------------------------------------------
% Private functions
% -------------------------------------------------------------------------

function [cost, grad_cost] = casadi_codegen(u,p,phi,build_directory)
[cost, grad_cost] = casadi_generate_c_code(u, p, phi,build_directory);
current_dir = pwd();
cd(fullfile(build_directory, 'icasadi'));
system('cargo build --release'); % builds casadi
cd(current_dir);




function open_impose_bounds(fid_main, constraints)
switch constraints.get_type()
    case 'ball'
        cstr_params = constraints.get_params();
        if ~(isfield(cstr_params, 'centre') && isempty(cstr_params.centre))
            fprintf(fid_main, '\n\t\tlet bounds = Ball2::new_at_origin_with_radius(%f);\n', cstr_params.radius);
        end
    case 'no_constraints'
        fprintf(fid_main, '\n\t\tlet bounds = NoConstraints::new();\n');
    otherwise
        fprintf(fid_main, '\n\t\tlet bounds = NoConstraints::new();\n');
end



function main1(fid_main, opEnBuilder)
fprintf(fid_main, '\n\tlet socket = UdpSocket::bind("%s:%d").expect("could not bind to address");\n', ...
    opEnBuilder.udp_interface.bind_address, opEnBuilder.udp_interface.port);
fprintf(fid_main, '\tsocket.set_read_timeout(None).expect("set_read_timeout failed");\n');
fprintf(fid_main, '\tsocket.set_write_timeout(None).expect("set_write_timeout failed");\n');    
fprintf(fid_main, '\tprintln!("Server started and listening at %s:%d");\n', ...
    opEnBuilder.udp_interface.bind_address, opEnBuilder.udp_interface.port);

function copy_into_main(fid_main, other_file)
fid_other = fopen(other_file, 'r');
fwrite(fid_main, fread(fid_other));
fclose(fid_other);


function codegen_const(fid_main, opEnBuilder, u, p)
fprintf(fid_main, '\nconst TOLERANCE: f64 = %g;\n', opEnBuilder.solver.tolerance);
fprintf(fid_main, 'const LBFGS_MEMORY: usize = %d;\n', opEnBuilder.solver.lbfgs_mem);
fprintf(fid_main, 'const MAX_ITERS: usize = %d;\n', opEnBuilder.solver.max_iters);
fprintf(fid_main, 'const NU: usize = %d;\n', length(u));
fprintf(fid_main, 'const NP: usize = %d;\n\n', length(p));
fprintf(fid_main, 'const COMMUNICATION_BUFFER: usize = %d;\n\n', opEnBuilder.communication_buffer_size);

function codegen_head(opEnBuilder)
head_file_path = fullfile(matlab_open_root, 'matlab', 'private', 'codegen_head.txt');
main_file = fullfile(opEnBuilder.build_path, opEnBuilder.build_name, 'src', 'main.rs');
copyfile(head_file_path, main_file);



function clean_destination(opEnBuilder)
destination_dir = fullfile(opEnBuilder.build_path, opEnBuilder.build_name);
if ~exist(destination_dir, 'dir')
    mkdir(destination_dir);
    init_cargo(opEnBuilder);
end


function open_generate_cargo(opEnBuilder)
cargo_file_name = 'Cargo.toml';
cargo_file_path = fullfile(opEnBuilder.build_path, ...
    opEnBuilder.build_name, cargo_file_name);
fid_cargo = fopen(cargo_file_path, 'w');

fprintf(fid_cargo, '[package]\nname = "%s"\n', opEnBuilder.build_name);
fprintf(fid_cargo, 'version = "%s"\n', opEnBuilder.version);
fprintf(fid_cargo, 'license = "%s"\n', opEnBuilder.license);
fprintf(fid_cargo, 'authors = [');
for i=1:length(opEnBuilder.authors)-1
    fprintf(fid_cargo, '"%s", ', opEnBuilder.authors{i});
end
fprintf(fid_cargo, '"%s"]\n', opEnBuilder.authors{end});
fprintf(fid_cargo, 'edition = "2018"\npublish=false\n');

fprintf(fid_cargo, '\n\n[dependencies]\noptimization_engine = "0.3.1"\n');
fprintf(fid_cargo, 'icasadi = {path = "./icasadi/"}\nserde = { version = "1.0", features = ["derive"] }\n');
fprintf(fid_cargo, 'serde_json = "1.0"\n');

fclose(fid_cargo);



function init_cargo(opEnBuilder)
current_path = pwd();
cd(fullfile(opEnBuilder.build_path, opEnBuilder.build_name));
system('cargo init');
cd(current_path);



function build_autogenerated_project(opEnBuilder)
current_path = pwd();
destination_path = fullfile(opEnBuilder.build_path, opEnBuilder.build_name);
cd(destination_path);
build_cmd = 'cargo build';
if ~isempty(opEnBuilder.target) && strcmp(opEnBuilder.target, 'rpi')
    fprintf('[codegen] Setting target: arm-unknown-linux-gnueabihf (ARMv6/Raspberry Pi)\n');
    opEnBuilder.target = 'arm-unknown-linux-gnueabihf';
end
if ~isempty(opEnBuilder.target) && ~strcmp(opEnBuilder.target, 'default')
    build_cmd = strcat(build_cmd, ' --target=', opEnBuilder.target);
end
if ~isempty(opEnBuilder.build_mode) && strcmp(opEnBuilder.build_mode, 'release')
    build_cmd = strcat(build_cmd, ' --release');
end
fprintf('[codegen] Build command: %s\n', build_cmd);
system(build_cmd);
cd(current_path);
% This script generates several plots and a tex file in the output/ directory
% Two main modes: 
%	universe_only = 0 -- separate figure for each code
%	universe_only = 1 -- one figure with all codes (universe_*.eps plot)
%
% For this script to work you need to compile me_ldpc/compute_ab. For this call (from Matlab):
% > cd me_ldpc; mex compute_ab.c
% 

% Universe only
universe_only = 1;
skip_cc48 = 1;

% Can be AWGN or BIAWGN
channel = 'BIAWGN';

load_awgncodes

% These are to sort codes in classes
%          b     blue          .     point              -     solid
%          g     green         o     circle             :     dotted
%          r     red           x     x-mark             -.    dashdot 
%          c     cyan          +     plus               --    dashed   
%          m     magenta       *     star             (none)  no line
%          y     yellow        s     square
%          k     black         d     diamond
%                              v     triangle (down)
%                              ^     triangle (up)
%                              <     triangle (left)
%                              >     triangle (right)
%                              p     pentagram
%                              h     hexagram

CLASSES = struct('class', [], ...
	'plot', {'-kx', '-b+', '-g*', '-rs', '-kd', '-b^', '-gp', '-rh', '--ko', '--r+', '-bo', '-go', '-ro'}, ...
	'idxs', [0]);

addpath ./../

N_codes = size(CODES,2);
figure(1);

last_class = 0;

for idx = 1:N_codes;
	Nmin = 10;
	Nmax = max(500, ceil(1.1*CODES(idx).n));
	epsil = CODES(idx).pe;
	code_rate = (CODES(idx).k)/(CODES(idx).n);
	ebno = 10^((CODES(idx).ebno)/10);
	A = sqrt(2*code_rate*ebno);
	if (strcmp(channel,'AWGN'))
		C = cap_awgn(A);
		K = k_awgn(A, epsil);
	elseif (strcmp(channel,'BIAWGN'))
		[C V] = biawgn_stats(A^2);
		K = sqrt(V)*norminv(epsil, 0, 1);
	end
	Ns_cap = floor(linspace(0, Nmax, 9));
	Capr = C + 0 .* Ns_cap;
	
	Ns_norm = floor(linspace(80, Nmax));
	nrm = C*Ns_norm + K*sqrt(Ns_norm) + log2(Ns_norm)/2;
	Ns_norm_add = floor(linspace(10,80));
	nrm_add= C*Ns_norm_add + K*sqrt(Ns_norm_add) + log2(Ns_norm)/2;

	found = 0;

	for cc=1:last_class;
		if (strcmp(CLASSES(cc).class, CODES(idx).name));
			CLASSES(cc).idxs = [CLASSES(cc).idxs idx];
			found = 1;
			break;
		end
	end
	
	if (~found)
		% Exclude a few elements
		if (strcmp(CODES(idx).name, 'Hamming')) || ...
			(strcmp(CODES(idx).name, 'Golay')) || ...
			(strcmp(CODES(idx).name, 'Quadratic residue')) || ...
			((universe_only) && (strcmp(CODES(idx).name, 'Convolutional (7,1/2)'))) ||...
			... %
			... % kill Reed-Solomon plot from BIAWGN -- it is too wiggly; see my email to Tal and Vardy 
			... % on May 26, 2012 for explanation
			... %
			(strcmp(channel, 'BIAWGN') && (strcmp(CODES(idx).name, 'Reed-Solomon (SDD)'))) ||...
			((skip_cc48) && strcmp(CODES(idx).name, 'Convolutional (7,1/2)') && (CODES(idx).n == 48))
			disp(sprintf('-- Summary: skipping: %s (%d, %d).', ...
					CODES(idx).name, CODES(idx).n, CODES(idx).k));
		else
			last_class = last_class + 1;
			if(last_class > size(CLASSES, 2))
				disp('ERROR: too many classes!');
				error('plot_universe');
			end
			CLASSES(last_class).class = CODES(idx).name;
			CLASSES(last_class).idxs = idx;
		end
	end

	if(universe_only)
		continue;
	end

	figure(1); fig1=gcf; axes('FontSize', 14);
		plot(Ns_cap, Capr, 'k-x', 'LineWidth', 1.0);
		hold on;
		%plot(Ns, conv./Ns, '-', 'LineWidth', 1.0, 'Color', [1 .2 0]);
		%plot(Ns, ach./Ns, '-', 'LineWidth', 1.0, 'Color', [0 .1 1]);
		plot(Ns_norm, nrm./Ns_norm, 'k-', 'LineWidth', 1.0);
		plot(CODES(idx).n, code_rate, 'r*', 'MarkerSize', 10.0, 'LineWidth', 1.5);
		plot(Ns_norm_add, nrm_add./Ns_norm_add, 'k--', 'LineWidth', 1.0);
		xlabel('Blocklength, n'); ylabel('Rate, bit/ch.use');
		min_rate = 0.9*min([code_rate nrm(1)/Ns_norm(1)]);
		max_rate = 1.1*C;
		ylim([min_rate max_rate]);
		grid on;
		legend('Capacity', 'Normal approximation', ...
				sprintf('Code: %s (%d, %d)', CODES(idx).name, CODES(idx).n, CODES(idx).k),...
			       	'Location', 'SouthEast');
		title(sprintf(['Channel: ' channel '(SNR=%.2f dB), \\epsilon = %g'],20*log10(A), epsil));
		set(fig1, 'PaperPositionMode', 'manual');
		set(fig1, 'PaperPosition', [0 0 12 9]);
		figure(fig1); print('-depsc2', ['output/' CODES(idx).fname]);
		close(gcf);
end

if(universe_only)
	ftex = fopen('/dev/null', 'w');
else
	ftex = fopen('output/fig_all.tex', 'w');
end
	
fprintf(ftex, '%% This file is autogenerated by plot_universe.m on %s\n\n', date);

fprintf(ftex, [	' Here is a list of all figures and the codes that appear on them '...
		'(for a summary see Fig.~\\ref{fig:dol_sum}:\n' ...
		'\\begin{enumerate}\n']);
for idx=1:N_codes;	
	code_rate = (CODES(idx).k)/(CODES(idx).n);
	ebno = 10^((CODES(idx).ebno)/10);
	A = sqrt(2*code_rate*ebno);
	fprintf(ftex, ['\\item Fig.~\\ref{fig:dol%d}: code: %s $(%d, %d)$, ' ...
				'channel: ' channel '($%.2f$ dB), Eb/No=$%.2f$ dB, Pe = $%g$. %s\n'], ...
				 idx, CODES(idx).name, CODES(idx).n, CODES(idx).k, ...
					20*log10(A), CODES(idx).ebno, CODES(idx).pe, CODES(idx).comment);
end
fprintf(ftex, '\\end{enumerate}\n\n');

% Generate a summary figure
base_pe = 1e-4;

figure(1); fig1=gcf; axes('FontSize', 14);
leg = {''};
for cc=1:last_class;
	cls_size = size(CLASSES(cc).idxs, 2);
	blocklens=[];
	normrates = [];
	for kk=1:cls_size;
		idx = CLASSES(cc).idxs(kk);
		epsil = CODES(idx).pe;
		code_rate = (CODES(idx).k)/(CODES(idx).n);
		ebno = 10^((CODES(idx).ebno)/10);

		A = sqrt(2*code_rate*ebno);
		if (strcmp(channel,'AWGN'))
			C = cap_awgn(A);
			K = k_awgn(A, epsil);
		elseif (strcmp(channel,'BIAWGN'))
			[C V] = biawgn_stats(A^2);
			K = sqrt(V)*norminv(epsil, 0, 1);
		end
		if(epsil ~= base_pe)
			disp(sprintf('ERROR: epsil != base_pe for the code with idx=%d\n', idx));
			error('plot_universe');
		end
		bllen = CODES(idx).n;
		normrate = CODES(idx).k/(bllen*C + K*sqrt(bllen) + log2(bllen)/2);
		blocklens = [blocklens bllen];
		normrates = [normrates normrate];
	end
	plotstr = CLASSES(cc).plot;
	if(cls_size == 1)
		if (strcmp(plotstr(1:2), '--'))
			plotstr = plotstr(3:end);
		elseif (plotstr(1)=='-')
			plotstr = plotstr(2:end);
		end
	end
	semilogx(blocklens, normrates, plotstr, 'LineWidth', 1.0, 'MarkerSize', 7.0);
	if(cc == 1)
		hold on;
	end
	leg(cc) = {CLASSES(cc).class};
end
ylim([0.5 1.1]); grid on;
title(sprintf(['Normalized rates of code families over ' channel ', Pe=%g'], base_pe));
xlabel('Blocklength, n'); ylabel('Normalized rate');
legend(leg); legend('Location', 'SouthWest');
set(fig1, 'PaperPositionMode', 'manual');
set(fig1, 'PaperPosition', [0 0 12 9]);
figure(fig1); 
if(universe_only)
	xlim([10^2 10^5]); ylim([0.5 1.0]);
	if (strcmp(channel, 'BIAWGN'))
		ylim([0.6 1.0]);
	end
	legend('Location', 'EastOutside');
	print('-depsc2', ['output/universe_' lower(channel) '.eps']);
else
	print('-depsc2', 'output/summary.eps');
end

rmpath ./../

fprintf(ftex,[	'\\begin{figure}[t]\n'...
		'\\centering\n' ...
		'\\vskip -10pt\n' ...
		'\\includegraphics[width=.94\\textwidth]{summary.eps}\n' ...
		'\\vskip -10pt\n' ...
		'\\caption{Normalized rates $R\\over C - \\sqrt{V\\over n}Q^{-1}(P_e)$: ' channel ', Pe = $%g$.}\n' ...
		'\\label{fig:dol_sum}\n' ...
		'\\end{figure}\n\n'], base_pe);

for idx=1:N_codes;
	code_rate = (CODES(idx).k)/(CODES(idx).n);
	ebno = 10^((CODES(idx).ebno)/10);
	A = sqrt(2*code_rate*ebno);
	fprintf(ftex,[	'\\begin{figure}[p]\n'...
			'\\centering\n' ...
			'\\vskip -10pt\n' ...
			'\\includegraphics[height=.4\\textheight]{%s}\n' ...
			'\\vskip -10pt\n' ...
			'\\caption{Comparison against: %s $(%d, %d)$, ' channel '($%.2f$ dB), Pe = $%g$.}\n' ...
			'\\label{fig:dol%d}\n' ...
			'\\end{figure}\n'], ...
			CODES(idx).fname, CODES(idx).name, CODES(idx).n, CODES(idx).k, ...
				20*log10(A), CODES(idx).pe, idx);
	if( (idx/2) == floor(idx/2) )
		fprintf(ftex, '\\clearpage\n\n');
	else
		fprintf(ftex, '\n');
	end
end
